check() {
    local domain
    domain="$(read_installed_domain)"
    local port
    port="$(read_public_port)"

    [[ -n "${domain}" ]] || die "Proxy is not installed (no nginx stream config found)"

    local pass="${GREEN}PASS${NC}"
    local fail="${RED}FAIL${NC}"
    local warn_label="${YELLOW}WARN${NC}"
    local results=()
    local all_ok=true

    echo -e "\n${BOLD}=== Proxy Stealth Check Report ===${NC}"
    echo -e "  Port:    ${port}"
    echo -e "  FakeTLS: ${domain}"
    echo -e "  Date:    $(date -u '+%Y-%m-%d %H:%M:%S UTC')\n"

    step "Services"
    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        echo -e "  [$(echo -e "${pass}")] mtg is running"
        results+=("mtg: OK")
    else
        echo -e "  [$(echo -e "${fail}")] mtg is NOT running"
        results+=("mtg: FAILED")
        all_ok=false
    fi

    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "  [$(echo -e "${pass}")] nginx is running"
        results+=("nginx: OK")
    else
        echo -e "  [$(echo -e "${fail}")] nginx is NOT running"
        results+=("nginx: FAILED")
        all_ok=false
    fi

    step "HTTP check (port 80 → should return 503)"
    local http_code
    http_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1/" 2>/dev/null || echo "ERR")"
    if [[ "${http_code}" == "503" ]]; then
        echo -e "  [$(echo -e "${pass}")] HTTP 80 returns ${http_code}"
        results+=("HTTP 80: OK (503)")
    else
        echo -e "  [$(echo -e "${fail}")] HTTP 80 returned ${http_code} (expected 503)"
        results+=("HTTP 80: FAIL (got ${http_code})")
        all_ok=false
    fi

    step "HTTPS check (port ${port} with random SNI → should return 503)"
    local https_code
    https_code="$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 \
        --resolve "test.example.com:${port}:127.0.0.1" \
        "https://test.example.com:${port}/" 2>/dev/null || echo "ERR")"
    if [[ "${https_code}" == "503" ]]; then
        echo -e "  [$(echo -e "${pass}")] HTTPS ${port} (random SNI) returns ${https_code}"
        results+=("HTTPS ${port} decoy: OK (503)")
    else
        echo -e "  [$(echo -e "${fail}")] HTTPS ${port} (random SNI) returned ${https_code} (expected 503)"
        results+=("HTTPS ${port} decoy: FAIL (got ${https_code})")
        all_ok=false
    fi

    step "TLS certificate (port ${port} with FakeTLS SNI)"
    local cert_info
    cert_info="$(echo | timeout 5 openssl s_client \
        -connect "127.0.0.1:${port}" \
        -servername "${domain}" 2>/dev/null \
        | openssl x509 -noout -subject -enddate 2>/dev/null || true)"
    if echo "${cert_info}" | grep -q "CN.*${domain}"; then
        local cn
        cn="$(echo "${cert_info}" | grep -oP 'CN\s*=\s*\K[^\n,]+')"
        local exp
        exp="$(echo "${cert_info}" | grep -oP 'notAfter=\K.+')"
        echo -e "  [$(echo -e "${pass}")] Certificate CN=${BOLD}${cn}${NC}"
        echo -e "         Expires: ${exp}"
        results+=("TLS cert: OK (CN=${cn})")
    else
        echo -e "  [$(echo -e "${fail}")] Could not verify certificate for ${domain}"
        results+=("TLS cert: FAIL")
        all_ok=false
    fi

    step "SNI routing (FakeTLS domain → mtg internal, other → decoy)"
    local mtg_port
    mtg_port="$(grep -Po 'bind-to = "127\.0\.0\.1:\K[0-9]+' "${CONFIG_FILE}" 2>/dev/null || true)"
    if [[ -n "${mtg_port}" ]]; then
        if ss -tlnp 2>/dev/null | grep -q "127.0.0.1:${mtg_port}"; then
            echo -e "  [$(echo -e "${pass}")] mtg listening on 127.0.0.1:${mtg_port} (internal)"
            results+=("SNI routing: OK (mtg on :${mtg_port})")
        else
            echo -e "  [$(echo -e "${warn_label}")] mtg port ${mtg_port} not detected in ss output"
            results+=("SNI routing: WARN")
        fi
    else
        echo -e "  [$(echo -e "${warn_label}")] Could not read internal port from config"
        results+=("SNI routing: WARN")
    fi

    step "SNI certificate routing check"
    local decoy_cn decoy_issuer real_cn real_issuer
    decoy_cn="$(echo | timeout 5 openssl s_client \
        -connect "127.0.0.1:${port}" \
        -servername "random.example.com" 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null \
        | grep -oP 'CN\s*=\s*\K[^\n,]+' || true)"
    decoy_issuer="$(echo | timeout 5 openssl s_client \
        -connect "127.0.0.1:${port}" \
        -servername "random.example.com" 2>/dev/null \
        | openssl x509 -noout -issuer 2>/dev/null \
        | grep -oP 'CN\s*=\s*\K[^\n,]+' || true)"
    real_cn="$(echo | timeout 5 openssl s_client \
        -connect "127.0.0.1:${port}" \
        -servername "${domain}" 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null \
        | grep -oP 'CN\s*=\s*\K[^\n,]+' || true)"
    real_issuer="$(echo | timeout 5 openssl s_client \
        -connect "127.0.0.1:${port}" \
        -servername "${domain}" 2>/dev/null \
        | openssl x509 -noout -issuer 2>/dev/null \
        | grep -oP 'O\s*=\s*\K[^,/]+' || true)"

    if [[ "${decoy_cn}" == "${decoy_issuer}" ]]; then
        echo -e "  [$(echo -e "${pass}")] Random SNI → self-signed cert (CN=${decoy_cn}, issuer=self)"
        results+=("SNI cert decoy: OK (self-signed)")
    else
        echo -e "  [$(echo -e "${warn_label}")] Random SNI → unexpected cert (CN=${decoy_cn}, issuer=${decoy_issuer})"
        results+=("SNI cert decoy: WARN")
    fi

    if [[ -n "${real_cn}" && "${real_cn}" == *"${domain#www.}"* ]]; then
        echo -e "  [$(echo -e "${pass}")] FakeTLS SNI → real cert (CN=${real_cn}, issuer=${real_issuer})"
        results+=("SNI cert FakeTLS: OK (real cert)")
    else
        echo -e "  [$(echo -e "${fail}")] FakeTLS SNI → unexpected cert (CN=${real_cn})"
        results+=("SNI cert FakeTLS: FAIL")
        all_ok=false
    fi

    step "External visibility (what scanners see on port ${port})"
    local tls_proto
    tls_proto="$(echo | timeout 5 openssl s_client \
        -connect "127.0.0.1:${port}" \
        -servername "scanner-bot.net" 2>/dev/null \
        | grep -oP 'Protocol\s*:\s*\K\S+' || true)"
    local tls_cipher
    tls_cipher="$(echo | timeout 5 openssl s_client \
        -connect "127.0.0.1:${port}" \
        -servername "scanner-bot.net" 2>/dev/null \
        | grep -oP 'Cipher\s*:\s*\K\S+' || true)"
    if [[ -n "${tls_proto}" ]]; then
        echo -e "  [$(echo -e "${pass}")] Scanner sees TLS server: ${tls_proto} / ${tls_cipher}"
        results+=("External: TLS visible (${tls_proto})")
    else
        echo -e "  [$(echo -e "${warn_label}")] Could not establish TLS with random SNI"
        results+=("External: WARN")
    fi

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD} Summary${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for r in "${results[@]}"; do
        echo "  ${r}"
    done
    echo ""
    if [[ "${all_ok}" == true ]]; then
        echo -e "  ${GREEN}${BOLD}All checks passed. Traffic is hidden.${NC}\n"
    else
        echo -e "  ${RED}${BOLD}Some checks failed. Review the output above.${NC}\n"
    fi
}

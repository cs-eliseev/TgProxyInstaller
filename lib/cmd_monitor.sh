read_installed_domain() {
    grep -Po '^\s+\K\S+(?=\s+127\.0\.0\.1)' "${NGINX_STREAM_CONF}" 2>/dev/null | head -1 || true
}

read_public_port() {
    grep -Po 'listen \K[0-9]+' "${NGINX_STREAM_CONF}" 2>/dev/null | head -1 || echo "443"
}

monitor() {
    require_root

    local domain
    domain="$(read_installed_domain)"
    local port
    port="$(read_public_port)"

    [[ -n "${domain}" ]] || die "Proxy is not installed (no nginx stream config found)"

    if ! command -v tshark &>/dev/null && ! command -v tcpdump &>/dev/null; then
        step "Installing tcpdump"
        case "${PKG_MGR:-apt}" in
            apt)    apt-get install -y -qq tcpdump ;;
            yum)    yum install -y -q tcpdump ;;
            dnf)    dnf install -y -q tcpdump ;;
            pacman) pacman -Sy --noconfirm --quiet tcpdump ;;
        esac
    fi

    local iface
    iface="$(ip route get 1.1.1.1 2>/dev/null | grep -Po 'dev \K\S+' | head -1 || echo "any")"

    echo -e "\n${BOLD}=== Live Traffic Monitor (port ${port}) ===${NC}"
    echo -e "  Interface: ${iface}"
    echo -e "  FakeTLS domain: ${CYAN}${domain}${NC}"
    echo -e "  ${GREEN}■${NC} = Telegram client   ${RED}■${NC} = browser / scanner\n"
    echo -e "  Press ${BOLD}Ctrl+C${NC} to stop.\n"

    if command -v tshark &>/dev/null; then
        tshark -i "${iface}" -f "tcp port ${port}" \
            -T fields -e ip.src -e tls.handshake.extensions_server_name \
            -l 2>/dev/null | \
        while IFS=$'\t' read -r src sni; do
            [[ -z "${src}" ]] && continue
            if [[ "${sni}" == "${domain}" ]]; then
                echo -e "  ${GREEN}■ Telegram${NC}  src=${src}  SNI=${BOLD}${sni}${NC}"
            elif [[ -n "${sni}" ]]; then
                echo -e "  ${RED}■ Browser/bot${NC}  src=${src}  SNI=${BOLD}${sni}${NC}"
            fi
        done
    else
        local cur_src=""
        tcpdump -i "${iface}" -l -nn -A "tcp port ${port}" 2>/dev/null | \
        while IFS= read -r line; do
            if [[ "${line}" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+[[:space:]]IP ]]; then
                if echo "${line}" | grep -qE "[0-9]+\.${port}:"; then
                    cur_src="$(echo "${line}" | \
                        grep -oP '\d+\.\d+\.\d+\.\d+(?=\.\d+\s+>)' | head -1 || true)"
                fi
                continue
            fi
            if echo "${line}" | grep -qa "${domain}"; then
                echo -e "  ${GREEN}■ Telegram${NC}  src=${cur_src:-?}  SNI=${BOLD}${domain}${NC}"
                cur_src=""
                continue
            fi
            if [[ -n "${cur_src}" ]]; then
                local sni
                sni="$(echo "${line}" | \
                    grep -oaP '(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,10}' | \
                    awk 'length >= 7' | head -1 || true)"
                if [[ -n "${sni}" && "${sni}" != "${domain}" ]]; then
                    echo -e "  ${RED}■ Browser/bot${NC}  src=${cur_src}  SNI=${BOLD}${sni}${NC}"
                    cur_src=""
                fi
            fi
        done
    fi
}

interactive_setup() {
    local pre_port="${1:-}"
    local pre_domain="${2:-}"

    local def_port="${pre_port:-${DEFAULT_PORT}}"

    echo -ne "  Port [${def_port}]: "
    read -r input_port
    PORT="${input_port:-${def_port}}"
    if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        die "Invalid port: ${PORT}"
    fi

    echo ""
    echo -ne "  Hide traffic with FakeTLS domain? [Y/n]: "
    read -r input_faketls
    if [[ "${input_faketls,,}" =~ ^(y|yes|)$ ]]; then
        USE_FAKETLS=true
        local def_domain="${pre_domain:-${DEFAULT_FAKE_TLS_DOMAIN}}"
        echo -ne "  FakeTLS domain [${def_domain}]: "
        read -r input_domain
        FAKE_TLS_DOMAIN="${input_domain:-${def_domain}}"
        FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN#http://}"
        FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN#https://}"
        FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN%%/*}"
        INTERNAL_PORT=$(( RANDOM % 50000 + 10000 ))
    else
        USE_FAKETLS=false
        FAKE_TLS_DOMAIN=""
        INTERNAL_PORT=0
    fi

    echo ""
    echo -ne "  Create fake 503 decoy for browsers/scanners? [Y/n]: "
    read -r input_decoy
    if [[ "${input_decoy,,}" =~ ^(y|yes|)$ ]]; then
        USE_DECOY=true
    else
        USE_DECOY=false
    fi

    echo ""
    echo -e "  ${BOLD}Installation parameters:${NC}"
    echo -e "    Port:          ${PORT}"
    if [[ "${USE_FAKETLS}" == true ]]; then
        echo -e "    FakeTLS:       ${FAKE_TLS_DOMAIN}"
        echo -e "    Internal port: ${INTERNAL_PORT} (mtg, localhost only)"
    else
        echo -e "    FakeTLS:       disabled (dd secret, mtg on port directly)"
    fi
    if [[ "${USE_DECOY}" == true ]]; then
        echo -e "    Decoy page:    enabled (503 for browsers)"
    else
        echo -e "    Decoy page:    disabled"
    fi
    echo ""
    echo -ne "  Proceed? [Y/n]: "
    read -r confirm
    [[ "${confirm,,}" =~ ^(y|yes|)$ ]] || { info "Installation cancelled."; exit 0; }
}

print_connection_info() {
    local port="${1}"
    local domain="${2}"
    step "Connection info"
    get_public_ip

    local tg_link="tg://proxy?server=${PUBLIC_IP}&port=${port}&secret=${SECRET}"
    local tme_link="https://t.me/proxy?server=${PUBLIC_IP}&port=${port}&secret=${SECRET}"

    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              Proxy installed successfully!            ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Server:${NC}    ${PUBLIC_IP}"
    echo -e "  ${BOLD}Port:${NC}      ${port}"
    echo -e "  ${BOLD}Secret:${NC}    ${SECRET}"
    [[ "${USE_FAKETLS}" == true ]] && echo -e "  ${BOLD}FakeTLS:${NC}   ${domain}"
    echo ""
    echo -e "  ${BOLD}Telegram link:${NC}"
    echo -e "  ${GREEN}${tg_link}${NC}"
    echo ""
    echo -e "  ${BOLD}Alternative link:${NC}"
    echo -e "  ${YELLOW}${tme_link}${NC}"
    echo ""
    echo -e "  ${BOLD}What visitors see:${NC}"
    echo -e "    Telegram client  → proxy works"
    [[ "${USE_DECOY}" == true ]] && echo -e "    Browser / bot    → 503 maintenance page"
    echo ""
    echo -e "  ${BOLD}Service management:${NC}"
    echo -e "    sudo systemctl status ${SERVICE_NAME}"
    echo -e "    sudo systemctl restart ${SERVICE_NAME}"
    echo -e "    sudo journalctl -u ${SERVICE_NAME} -f"
    echo ""
    echo -e "  ${BOLD}Uninstall:${NC}  sudo bash $0 uninstall"
    echo ""

    {
        echo "=== Telegram MTProto Proxy — Connection Info ==="
        echo "Installed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo ""
        echo "Server:   ${PUBLIC_IP}"
        echo "Port:     ${port}"
        echo "Secret:   ${SECRET}"
        [[ "${USE_FAKETLS}" == true ]] && echo "FakeTLS:  ${domain}"
        echo ""
        echo "Link (tg://):"
        echo "${tg_link}"
        echo ""
        echo "Link (t.me):"
        echo "${tme_link}"
    } > "${CONFIG_DIR}/connection.txt"
    info "Connection info saved to ${CONFIG_DIR}/connection.txt"
}

status() {
    echo -e "\n${BOLD}=== Telegram MTProto Proxy Status ===${NC}"

    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        echo -e "  mtg:   ${GREEN}Running${NC}"
    else
        echo -e "  mtg:   ${RED}Stopped${NC}"
    fi
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "  nginx: ${GREEN}Running${NC}"
    else
        echo -e "  nginx: ${RED}Stopped${NC}"
    fi

    if [[ -f "${CONFIG_DIR}/connection.txt" ]]; then
        echo ""
        cat "${CONFIG_DIR}/connection.txt"
    else
        warn "Proxy is not installed (config not found)"
    fi
}

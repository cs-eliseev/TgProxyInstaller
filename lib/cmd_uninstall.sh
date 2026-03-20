uninstall() {
    step "Removing Telegram MTProto Proxy"
    require_root

    for svc in "${SERVICE_NAME}" nginx; do
        systemctl is-active --quiet "${svc}" 2>/dev/null && systemctl stop "${svc}" || true
    done

    systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null || true
    systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null \
        && systemctl disable "${SERVICE_NAME}" --quiet || true

    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload

    rm -f "${BINARY_PATH}"
    rm -rf "${CONFIG_DIR}" "${LOG_DIR}"

    id "${MTG_USER}" &>/dev/null && userdel "${MTG_USER}" 2>/dev/null || true
    info "mtg removed"

    rm -f "${NGINX_DECOY_CONF}" "${NGINX_DECOY_CERT}" "${NGINX_DECOY_KEY}" "${NGINX_STREAM_CONF}"
    rm -rf "${NGINX_WEBROOT}"

    nginx -t &>/dev/null && systemctl restart nginx || true
    info "nginx config cleaned"

    info "Proxy fully removed"
    warn "Firewall rules and nginx.conf stream block were not removed — check manually"
}

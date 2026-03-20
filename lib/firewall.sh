configure_firewall() {
    local port="${1}"
    local ports_desc="${port}/tcp"
    [[ "${USE_DECOY}" == true ]] && ports_desc="80/tcp and ${port}/tcp"
    step "Configuring firewall (ports ${ports_desc})"

    _fw_allow() {
        local p="${1}"
        if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
            ufw allow "${p}/tcp" > /dev/null
            info "UFW: port ${p}/tcp allowed"
        elif command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
            firewall-cmd --permanent --add-port="${p}/tcp" > /dev/null
            firewall-cmd --reload > /dev/null
            info "firewalld: port ${p}/tcp allowed"
        elif command -v iptables &>/dev/null; then
            if ! iptables -C INPUT -p tcp --dport "${p}" -j ACCEPT &>/dev/null 2>&1; then
                iptables -I INPUT -p tcp --dport "${p}" -j ACCEPT
                if command -v iptables-save &>/dev/null; then
                    iptables-save > /etc/iptables/rules.v4 2>/dev/null \
                        || iptables-save > /etc/sysconfig/iptables 2>/dev/null \
                        || warn "Save iptables rules manually"
                fi
                info "iptables: port ${p}/tcp allowed"
            else
                info "iptables: rule for port ${p}/tcp already exists"
            fi
        else
            warn "No firewall detected. Open port ${p}/tcp manually."
        fi
    }

    [[ "${USE_DECOY}" == true ]] && _fw_allow 80
    _fw_allow "${port}"
}

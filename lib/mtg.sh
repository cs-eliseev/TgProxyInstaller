install_mtg() {
    step "Downloading mtg"

    local api_url="https://api.github.com/repos/9seconds/mtg/releases/latest"
    local release_json
    release_json="$(curl -sf "${api_url}" || die "Failed to fetch release data")"

    local version
    version="$(echo "${release_json}" | grep -Po '"tag_name":\s*"\K[^"]+' | head -1 || true)"
    [[ -n "${version}" ]] || die "Failed to determine mtg version"
    info "Latest mtg version: ${version}"

    local download_url
    download_url="$(echo "${release_json}" \
        | grep -Po '"browser_download_url":\s*"\K[^"]+' \
        | grep "linux-${ARCH}\.tar\.gz$" | head -1 || true)"
    [[ -n "${download_url}" ]] || die "No binary found for architecture ${ARCH}"

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    curl -sL "${download_url}" -o "${tmp_dir}/mtg.tar.gz" || die "Failed to download mtg"
    tar -xzf "${tmp_dir}/mtg.tar.gz" -C "${tmp_dir}" || die "Failed to extract archive"

    local tmp_bin
    tmp_bin="$(find "${tmp_dir}" -type f -name "mtg" | head -1 || true)"
    [[ -n "${tmp_bin}" ]] || die "Binary not found inside archive"

    chmod +x "${tmp_bin}"
    "${tmp_bin}" --version &>/dev/null || die "Downloaded binary is corrupted"
    mv "${tmp_bin}" "${BINARY_PATH}"
    rm -rf "${tmp_dir}"
    info "mtg ${version} installed to ${BINARY_PATH}"
}

create_user() {
    if ! id "${MTG_USER}" &>/dev/null; then
        useradd --system --no-create-home --shell /sbin/nologin "${MTG_USER}"
        info "System user '${MTG_USER}' created"
    else
        info "User '${MTG_USER}' already exists"
    fi
    mkdir -p "${LOG_DIR}" "${CONFIG_DIR}"
    chown "${MTG_USER}:${MTG_USER}" "${LOG_DIR}" "${CONFIG_DIR}"
}

generate_secret() {
    local domain="${1}"

    if [[ "${USE_FAKETLS}" == true ]]; then
        step "Generating FakeTLS secret (domain: ${domain})"
        local random_hex
        random_hex="$(openssl rand -hex 16)"
        local domain_hex=""
        local char
        for (( i=0; i<${#domain}; i++ )); do
            char="${domain:$i:1}"
            domain_hex+="$(printf '%02x' "'${char}")"
        done
        SECRET="ee${random_hex}${domain_hex}"
    else
        step "Generating secret"
        SECRET="dd$(openssl rand -hex 16)"
    fi

    echo "${SECRET}" > "${SECRET_FILE}"
    chown "${MTG_USER}:${MTG_USER}" "${SECRET_FILE}"
    chmod 600 "${SECRET_FILE}"
    info "Secret generated and saved to ${SECRET_FILE}"
}

write_config() {
    local port="${1}"
    local bind_addr
    if [[ "${USE_FAKETLS}" == true ]]; then
        bind_addr="127.0.0.1:${port}"
    else
        bind_addr="0.0.0.0:${port}"
    fi
    mkdir -p "${CONFIG_DIR}"
    cat > "${CONFIG_FILE}" <<EOF
secret = "${SECRET}"
bind-to = "${bind_addr}"
EOF
    chown "${MTG_USER}:${MTG_USER}" "${CONFIG_FILE}"
    chmod 640 "${CONFIG_FILE}"
    info "Config written: ${CONFIG_FILE}"
}

install_service() {
    local internal_port="${1}"
    step "Creating systemd service"

    cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Telegram MTProto Proxy (mtg)
Documentation=https://github.com/9seconds/mtg
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${MTG_USER}
Group=${MTG_USER}
ExecStart=${BINARY_PATH} run ${CONFIG_FILE}
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ReadWritePaths=${LOG_DIR} ${CONFIG_DIR}
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" --quiet
    systemctl restart "${SERVICE_NAME}"

    sleep 2
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        info "Service ${SERVICE_NAME} is running and enabled on boot"
    else
        warn "Service failed to start. Check: sudo journalctl -u ${SERVICE_NAME} -n 20 --no-pager"
        systemctl status "${SERVICE_NAME}" --no-pager -l >&2 || true
    fi
}

_nginx_decoy_html() {
    mkdir -p "${NGINX_WEBROOT}"
    cat > "${NGINX_WEBROOT}/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>503 Service Unavailable</title>
  <style>
    body { font-family: sans-serif; background: #f5f5f5; color: #333;
           display: flex; align-items: center; justify-content: center;
           min-height: 100vh; margin: 0; }
    .box { text-align: center; padding: 2rem; }
    h1   { font-size: 2rem; margin-bottom: .5rem; }
    p    { color: #666; }
  </style>
</head>
<body>
  <div class="box">
    <h1>503 Service Unavailable</h1>
    <p>The server is temporarily unable to service your request.<br>Please try again later.</p>
  </div>
</body>
</html>
HTML
}

enable_nginx_stream() {
    local nginx_conf="/etc/nginx/nginx.conf"

    if nginx -V 2>&1 | grep -q "with-stream=dynamic"; then
        if [[ ! -d "/etc/nginx/modules-enabled" ]] && \
           ! grep -rq "ngx_stream_module" /etc/nginx/ 2>/dev/null; then
            sed -i '1s|^|load_module modules/ngx_stream_module.so;\n|' "${nginx_conf}"
            info "Stream module load directive added to nginx.conf"
        fi
    fi

    if ! grep -q "stream.conf.d" "${nginx_conf}"; then
        cat >> "${nginx_conf}" <<'EOF'

stream {
    include /etc/nginx/stream.conf.d/*.conf;
}
EOF
        info "Stream block added to nginx.conf"
    fi
}

configure_nginx() {
    local public_port="${1}"
    local internal_port="${2}"
    local domain="${3}"

    step "Configuring nginx"
    rm -f /etc/nginx/sites-enabled/default

    if [[ "${USE_FAKETLS}" == true && "${USE_DECOY}" == true ]]; then
        _nginx_decoy_html
        openssl req -x509 -nodes -newkey rsa:2048 \
            -keyout "${NGINX_DECOY_KEY}" \
            -out "${NGINX_DECOY_CERT}" \
            -days 3650 \
            -subj "/CN=${domain}" \
            2>/dev/null
        info "Self-signed TLS certificate generated (CN=${domain})"

        cat > "${NGINX_DECOY_CONF}" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root ${NGINX_WEBROOT};

    location / { return 503; }
    error_page 503 /index.html;
    location = /index.html { internal; }
}

server {
    listen 127.0.0.1:${NGINX_DECOY_HTTPS_PORT} ssl;
    server_name _;

    ssl_certificate     ${NGINX_DECOY_CERT};
    ssl_certificate_key ${NGINX_DECOY_KEY};
    ssl_protocols       TLSv1.2 TLSv1.3;

    root ${NGINX_WEBROOT};

    location / { return 503; }
    error_page 503 /index.html;
    location = /index.html { internal; }
}
EOF

        mkdir -p "${NGINX_STREAM_DIR}"
        cat > "${NGINX_STREAM_CONF}" <<EOF
map \$ssl_preread_server_name \$stream_backend {
    ${domain}  127.0.0.1:${internal_port};
    default    127.0.0.1:${NGINX_DECOY_HTTPS_PORT};
}

server {
    listen ${public_port};
    proxy_pass \$stream_backend;
    ssl_preread on;
    proxy_connect_timeout 10s;
    proxy_timeout 1d;
}
EOF
        enable_nginx_stream

    elif [[ "${USE_FAKETLS}" == true && "${USE_DECOY}" == false ]]; then
        mkdir -p "${NGINX_STREAM_DIR}"
        cat > "${NGINX_STREAM_CONF}" <<EOF
map \$ssl_preread_server_name \$stream_backend {
    ${domain}  127.0.0.1:${internal_port};
    default    127.0.0.1:1;
}

server {
    listen ${public_port};
    proxy_pass \$stream_backend;
    ssl_preread on;
    proxy_connect_timeout 5s;
    proxy_timeout 1d;
}
EOF
        enable_nginx_stream

    elif [[ "${USE_FAKETLS}" == false && "${USE_DECOY}" == true ]]; then
        _nginx_decoy_html
        cat > "${NGINX_DECOY_CONF}" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root ${NGINX_WEBROOT};

    location / { return 503; }
    error_page 503 /index.html;
    location = /index.html { internal; }
}
EOF
    fi

    nginx -t || die "nginx config test failed"
    systemctl enable nginx --quiet
    systemctl restart nginx
    info "nginx configured and running"
}

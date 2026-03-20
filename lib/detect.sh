detect_os() {
    [[ -f /etc/os-release ]] || die "Unknown OS — /etc/os-release not found."
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"

    case "${OS_ID}" in
        ubuntu|debian|raspbian) PKG_MGR="apt" ;;
        centos|rhel|almalinux|rocky|ol) PKG_MGR="yum" ;;
        fedora) PKG_MGR="dnf" ;;
        arch|manjaro|endeavouros) PKG_MGR="pacman" ;;
        *)
            if [[ "${OS_ID_LIKE}" =~ debian ]]; then PKG_MGR="apt"
            elif [[ "${OS_ID_LIKE}" =~ rhel|fedora ]]; then PKG_MGR="yum"
            else die "Unsupported distribution: ${OS_ID}"; fi
            ;;
    esac
    info "OS: ${PRETTY_NAME:-${OS_ID}} (package manager: ${PKG_MGR})"
}

detect_arch() {
    local machine
    machine="$(uname -m)"
    case "${machine}" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armhf)  ARCH="armv7" ;;
        armv6l)        ARCH="armv6" ;;
        *) die "Unsupported architecture: ${machine}" ;;
    esac
    info "Architecture: ${machine} → ${ARCH}"
}

install_deps() {
    step "Installing dependencies"
    local need_nginx=false
    [[ "${USE_FAKETLS}" == true || "${USE_DECOY}" == true ]] && need_nginx=true

    case "${PKG_MGR}" in
        apt)
            apt-get update -qq
            if [[ "${need_nginx}" == true ]]; then
                apt-get install -y -qq curl openssl jq iptables nginx libnginx-mod-stream
            else
                apt-get install -y -qq curl openssl jq iptables
            fi
            ;;
        yum)
            if [[ "${need_nginx}" == true ]]; then
                yum install -y -q curl openssl jq iptables nginx nginx-mod-stream
            else
                yum install -y -q curl openssl jq iptables
            fi
            ;;
        dnf)
            if [[ "${need_nginx}" == true ]]; then
                dnf install -y -q curl openssl jq iptables nginx nginx-mod-stream
            else
                dnf install -y -q curl openssl jq iptables
            fi
            ;;
        pacman)
            if [[ "${need_nginx}" == true ]]; then
                pacman -Sy --noconfirm --quiet curl openssl jq iptables nginx
            else
                pacman -Sy --noconfirm --quiet curl openssl jq iptables
            fi
            ;;
    esac
    info "Dependencies installed"
}

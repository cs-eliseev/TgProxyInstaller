_log() {
    local level="$1"; shift
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    printf '[%s] [%-5s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "${level}" "$*" \
        >> "${LOG_FILE}" 2>/dev/null || true
}

info()  { echo -e "${GREEN}[✓]${NC} $*"; _log "INFO"  "$*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; _log "WARN"  "$*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; _log "ERROR" "$*"; }
step()  { echo -e "\n${BLUE}${BOLD}[→]${NC} $*"; _log "STEP"  "$*"; }
die()   { error "$*"; exit 1; }

banner() {
    echo -e "${CYAN}${BOLD}"
    cat <<'EOF'
  ╔══════════════════════════════════════════╗
  ║     Telegram MTProto Proxy Installer     ║
  ║          FakeTLS  •  Stealth Mode        ║
  ╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  Version: ${SCRIPT_VERSION}\n"
}

usage() {
    cat <<EOF
Usage: sudo bash $0 [OPTION]...

Options:
  -i, --install          Install the proxy (default)
  -u, --uninstall        Remove the proxy and clean up
  -s, --status           Show proxy and connection status
  -m, --monitor          Live traffic monitor (tcpdump)
  -V, --verify           Run stealth diagnostic report
  -p, --port PORT        Public port to listen on (default: ${DEFAULT_PORT})
  -t, --tls-domain DOMAIN  FakeTLS domain (default: ${DEFAULT_FAKE_TLS_DOMAIN})
  -d, --defaults         Non-interactive install, accept defaults
  -v, --version          Display version information
  -h, --help             Show this help and exit
EOF
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Run this script as root: sudo bash $0"
}

get_public_ip() {
    PUBLIC_IP=""
    for url in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com"; do
        PUBLIC_IP="$(curl -sf --max-time 5 "${url}" 2>/dev/null || true)"
        [[ -n "${PUBLIC_IP}" ]] && break
    done
    if [[ -z "${PUBLIC_IP}" ]]; then
        warn "Could not detect public IP automatically"
        PUBLIC_IP="<YOUR_IP>"
    fi
}

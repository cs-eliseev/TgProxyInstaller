#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/mtg.sh"
source "${SCRIPT_DIR}/lib/nginx.sh"
source "${SCRIPT_DIR}/lib/firewall.sh"
source "${SCRIPT_DIR}/lib/cmd_install.sh"
source "${SCRIPT_DIR}/lib/cmd_uninstall.sh"
source "${SCRIPT_DIR}/lib/cmd_status.sh"
source "${SCRIPT_DIR}/lib/cmd_monitor.sh"
source "${SCRIPT_DIR}/lib/cmd_check.sh"

main() {
    banner

    local cmd="install"
    local opt_port=""
    local opt_domain=""
    local opt_yes=false
    local orig_args="${*:-}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--install)   cmd="install" ;;
            -u|--uninstall) cmd="uninstall" ;;
            -s|--status)    cmd="status" ;;
            -m|--monitor)   cmd="monitor" ;;
            -V|--verify)    cmd="check" ;;
            -d|--defaults)  opt_yes=true ;;
            -v|--version)   echo "mtg-installer ${SCRIPT_VERSION}"; exit 0 ;;
            -h|--help)      usage; exit 0 ;;
            -p|--port)
                shift
                [[ $# -gt 0 ]] || die "Option --port requires an argument"
                opt_port="$1"
                ;;
            --port=*)       opt_port="${1#*=}" ;;
            -t|--tls-domain)
                shift
                [[ $# -gt 0 ]] || die "Option --tls-domain requires an argument"
                opt_domain="$1"
                ;;
            --tls-domain=*) opt_domain="${1#*=}" ;;
            *) die "Unknown option: $1. Use -h for help." ;;
        esac
        shift
    done

    require_root
    _log "----" "--- session: $0 ${orig_args} ---"

    case "${cmd}" in
        uninstall) uninstall; exit 0 ;;
        status)    status;    exit 0 ;;
        monitor)   detect_os; monitor; exit 0 ;;
        check)     check;     exit 0 ;;
    esac

    detect_os
    detect_arch

    if [[ "${opt_yes}" == true ]]; then
        PORT="${opt_port:-${DEFAULT_PORT}}"
        if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
            die "Invalid port: ${PORT}"
        fi
        USE_FAKETLS=true
        USE_DECOY=true
        FAKE_TLS_DOMAIN="${opt_domain:-${DEFAULT_FAKE_TLS_DOMAIN}}"
        FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN#http://}"
        FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN#https://}"
        FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN%%/*}"
        INTERNAL_PORT=$(( RANDOM % 50000 + 10000 ))
        echo -e "  ${BOLD}Installation parameters:${NC}"
        echo -e "    Port:          ${PORT}"
        echo -e "    FakeTLS:       ${FAKE_TLS_DOMAIN}"
        echo -e "    Internal port: ${INTERNAL_PORT} (mtg, localhost only)"
        echo -e "    Decoy page:    enabled"
        echo ""
    else
        interactive_setup "${opt_port}" "${opt_domain}"
    fi

    install_deps

    [[ -x "${BINARY_PATH}" ]] && warn "mtg is already installed. Reinstalling..."
    install_mtg

    create_user
    generate_secret "${FAKE_TLS_DOMAIN}"

    if [[ "${USE_FAKETLS}" == true ]]; then
        write_config "${INTERNAL_PORT}"
        install_service "${INTERNAL_PORT}"
    else
        write_config "${PORT}"
        install_service "${PORT}"
    fi

    if [[ "${USE_FAKETLS}" == true || "${USE_DECOY}" == true ]]; then
        configure_nginx "${PORT}" "${INTERNAL_PORT:-0}" "${FAKE_TLS_DOMAIN}"
    fi

    configure_firewall "${PORT}"
    print_connection_info "${PORT}" "${FAKE_TLS_DOMAIN}"
}

main "$@"

readonly SCRIPT_VERSION="1.4.0"
readonly SERVICE_NAME="mtg"
readonly BINARY_PATH="/usr/local/bin/mtg"
readonly CONFIG_DIR="/etc/mtg"
readonly CONFIG_FILE="${CONFIG_DIR}/config.toml"
readonly SECRET_FILE="${CONFIG_DIR}/secret"
readonly LOG_DIR="/var/log/mtg"
readonly LOG_FILE="${LOG_DIR}/installer.log"
readonly MTG_USER="mtg"

readonly -a FAKETLS_DOMAINS=(
    "www.microsoft.com"
    "www.google.com"
    "www.apple.com"
    "www.amazon.com"
    "www.cloudflare.com"
    "www.github.com"
    "www.netflix.com"
    "www.youtube.com"
    "www.linkedin.com"
    "www.twitter.com"
    "www.facebook.com"
    "www.instagram.com"
    "www.wikipedia.org"
    "www.dropbox.com"
    "www.adobe.com"
    "www.salesforce.com"
    "www.zoom.us"
    "www.slack.com"
    "www.stripe.com"
    "www.shopify.com"
    "www.paypal.com"
    "www.spotify.com"
    "www.twitch.tv"
    "www.reddit.com"
    "www.medium.com"
)
readonly DEFAULT_FAKE_TLS_DOMAIN="${FAKETLS_DOMAINS[RANDOM % ${#FAKETLS_DOMAINS[@]}]}"
readonly DEFAULT_PORT=443

readonly NGINX_STREAM_CONF="/etc/nginx/stream.conf.d/mtg.conf"
readonly NGINX_STREAM_DIR="/etc/nginx/stream.conf.d"
readonly NGINX_DECOY_CONF="/etc/nginx/conf.d/mtg-decoy.conf"
readonly NGINX_DECOY_CERT="/etc/nginx/mtg-decoy.crt"
readonly NGINX_DECOY_KEY="/etc/nginx/mtg-decoy.key"
readonly NGINX_WEBROOT="/var/www/mtg-decoy"
readonly NGINX_DECOY_HTTPS_PORT=8443

USE_FAKETLS=true
USE_DECOY=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

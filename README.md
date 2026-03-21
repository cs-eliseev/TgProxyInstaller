English | [Русский](README.ru.md)

# Telegram MTProto Proxy Installer

> **This is an educational project** created for learning purposes. It is not intended for production use.

Installs an MTProto proxy for Telegram on a Linux server. Traffic is disguised as regular HTTPS — the server looks like a normal website returning a maintenance page to browsers and scanners.

## Requirements

* Linux server (Ubuntu/Debian, CentOS/RHEL, Fedora, Arch)
* Root access
* Open port 443 (or any other you choose)

## Installation

Download and extract the project archive, then run the installer:

**Via Git:**

```bash
git clone https://github.com/cs-eliseev/TgProxyInstaller.git
cd CoreServerKit
chmod +x install.sh
```

**Via curl:**

```bash
curl -L https://github.com/cs-eliseev/TgProxyInstaller/archive/refs/heads/main.tar.gz | tar -xz
cd TgProxyInstaller
sudo bash install.sh
```

The installer will ask:

* **Port** — public port to listen on (default: 443)
* **FakeTLS domain** — the domain your traffic will mimic (default: www.microsoft.com)
* **Decoy page** — whether to show a 503 page to browsers and scanners

At the end you will receive a ready-to-use link for Telegram.

## Usage

```bash
sudo bash install.sh [OPTION]
```

| Option              | Description                           |
|---------------------|---------------------------------------|
| `-i`, `--install`   | Install the proxy (default)           |
| `-u`, `--uninstall` | Remove the proxy                      |
| `-s`, `--status`    | Show status and connection link       |
| `-m`, `--monitor`   | Live traffic monitor                  |
| `-V`, `--verify`    | Run diagnostic report                 |
| `-d`, `--defaults`  | Install without prompts, use defaults |
| `-p PORT`           | Set public port                       |
| `-t DOMAIN`         | Set FakeTLS domain                    |
| `-v`, `--version`   | Show version                          |
| `-h`, `--help`      | Show help                             |

## Examples

```bash
sudo bash install.sh
sudo bash install.sh -d
sudo bash install.sh -d -p 8443 -t www.google.com
sudo bash install.sh --status
sudo bash install.sh --uninstall
```

## After Installation

The proxy starts automatically on boot. To manage it:

```bash
sudo systemctl status mtg
sudo systemctl restart mtg
sudo journalctl -u mtg -f
```

Connection details (server, port, secret, links) are saved to `/etc/mtg/connection.txt`.

## License

[MIT](LICENSE)

[English](README.md) | Русский

# Установщик MTProto прокси для Telegram

> **Это учебный проект**, созданный в образовательных целях. Не предназначен для использования в продакшене.

Устанавливает MTProto прокси для Telegram на Linux-сервер.

## Требования

* Linux-сервер (Ubuntu/Debian, CentOS/RHEL, Fedora, Arch)
* Доступ root
* Открытый порт 443 (или любой другой на ваш выбор)

## Установка

Скачайте и распакуйте архив с проектом, затем запустите установщик:

**Через Git:**

```bash
git clone https://github.com/cs-eliseev/TgProxyInstaller.git
cd CoreServerKit
chmod +x install.sh
```

**Через curl:**

```bash
curl -L https://github.com/cs-eliseev/TgProxyInstaller/archive/refs/heads/main.tar.gz | tar -xz
cd TgProxyInstaller
sudo bash install.sh
```

В процессе установки будет задано несколько вопросов:

* **Порт** — публичный порт для подключений (по умолчанию: 443)
* **FakeTLS домен** — домен, под который будет маскироваться трафик (по умолчанию: www.microsoft.com)
* **Страница-заглушка** — показывать ли браузерам и сканерам страницу 503

По завершении будет выведена готовая ссылка для подключения в Telegram.

## Использование

```bash
sudo bash install.sh [ОПЦИЯ]
```

| Опция               | Описание                                           |
|---------------------|----------------------------------------------------|
| `-i`, `--install`   | Установить прокси (по умолчанию)                   |
| `-u`, `--uninstall` | Удалить прокси                                     |
| `-s`, `--status`    | Показать статус и ссылку для подключения           |
| `-m`, `--monitor`   | Мониторинг трафика в реальном времени              |
| `-V`, `--verify`    | Диагностический отчёт                              |
| `-d`, `--defaults`  | Установка без вопросов, с настройками по умолчанию |
| `-p PORT`           | Указать публичный порт                             |
| `-t DOMAIN`         | Указать FakeTLS домен                              |
| `-v`, `--version`   | Показать версию                                    |
| `-h`, `--help`      | Показать справку                                   |

## Примеры

```bash
sudo bash install.sh
sudo bash install.sh -d
sudo bash install.sh -d -p 8443 -t www.google.com
sudo bash install.sh --status
sudo bash install.sh --uninstall
```

## После установки

Прокси запускается автоматически при старте сервера. Управление сервисом:

```bash
sudo systemctl status mtg
sudo systemctl restart mtg
sudo journalctl -u mtg -f
```

Данные для подключения (сервер, порт, секрет, ссылки) сохраняются в `/etc/mtg/connection.txt`.

## Лицензия

[MIT](LICENSE)

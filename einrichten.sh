#!/bin/bash
# Einmalig auf dem Unraid-Server vor dem ersten "docker compose up" ausführen.
# Darf wiederholt laufen: vorhandene Passwörter und Daten bleiben unangetastet.
set -euo pipefail
cd "$(dirname "$0")"

APPDATA="${RS_APPDATA:-/mnt/user/appdata/resourcespace}"

if [ ! -f db.env ]; then
  pw() { head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32; }
  umask 077
  cat > db.env <<ENV
MYSQL_DATABASE=resourcespace
MYSQL_USER=resourcespace_rw
MYSQL_PASSWORD=$(pw)
MYSQL_ROOT_PASSWORD=$(pw)
ENV
  echo "db.env mit Zufallspasswörtern angelegt."
fi

if grep -q 'change-me' db.env; then
  echo "FEHLER: db.env enthält noch 'change-me'. Passwörter ersetzen oder db.env löschen und neu ausführen." >&2
  exit 1
fi

mkdir -p "$APPDATA/filestore" "$APPDATA/mariadb" "$APPDATA/config"

# Docker würde einen fehlenden Dateipfad als leeres Verzeichnis anlegen —
# danach kann die Einrichtungsseite config.php nicht schreiben.
if [ -d "$APPDATA/config/config.php" ]; then
  echo "FEHLER: $APPDATA/config/config.php ist ein Verzeichnis (von Docker angelegt)." >&2
  echo "        docker compose down; rmdir \"$APPDATA/config/config.php\"; dann erneut ausführen." >&2
  exit 1
fi
[ -e "$APPDATA/config/config.php" ] || touch "$APPDATA/config/config.php"

# Apache/PHP läuft im Abbild als www-data (33). Die Einrichtungsseite schreibt
# config.php, Uploads landen im filestore.
chown -R 33:33 "$APPDATA/filestore" "$APPDATA/config"
# Das mariadb-Verzeichnis richtet der MariaDB-Container beim ersten Start selbst ein.

echo "Fertig. Datenverzeichnis: $APPDATA"
echo "Weiter mit: docker compose up --build -d"

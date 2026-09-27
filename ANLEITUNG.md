# ResourceSpace auf Unraid

Grundlage: die offizielle Docker-Anleitung
(resourcespace.com/knowledge-base/systemadmin/install_docker) und das Repo
`github.com/resourcespace/docker`, Stand `07dbaff`. `Dockerfile`, `entrypoint.sh`
und `LICENSE` sind unverändert übernommen.

## Was gegenüber dem Original anders ist

| Original | Hier | Warum |
|---|---|---|
| Port `80:80` | `8088:80` (`RS_PORT`) | Port 80 belegt die Unraid-Weboberfläche |
| benannte Volumes | Ordner unter `/mnt/user/appdata/resourcespace` | werden von der Appdata-Sicherung erfasst |
| `mariadb` (latest) | `mariadb:11.4` (LTS) | kein ungewolltes Major-Upgrade der Datenbank beim Pull |
| `config.php` aus dem Repo-Ordner | `appdata/.../config/config.php` | Konfiguration gehört zu den Daten, nicht zum Quelltext |
| Container `mariadb` | `resourcespace-mariadb` | kollidiert nicht mit anderen Stacks |
| startet sofort | ResourceSpace wartet auf gesunde DB | Einrichtungsseite findet sonst beim ersten Start keine DB |
| Cron nur Hitcount | zusätzlich `batch/cron.php` täglich | Wartungsaufgaben liefen sonst nie |
| Passwörter `change-me` | `einrichten.sh` erzeugt Zufallspasswörter | |

## Verzeichnisse

| | wofür | Pfad |
|---|---|---|
| **Quelltext** | dieser Ordner, daraus wird gebaut | `/mnt/user/Software/Repositories/resourcespace` |
| **Daten** | Filestore, Datenbank, `config.php` | `/mnt/user/appdata/resourcespace` |

Andere Pfade: `RS_APPDATA=/pfad` vor `./einrichten.sh` **und** vor jedem
`docker compose`-Aufruf setzen (oder in eine `.env` neben `compose.yaml` schreiben).

## 1. Repo auf den Server holen

```bash
git clone https://github.com/luckylefti/resourcespace-unraid.git /mnt/user/Software/Repositories/resourcespace
```

Später aktualisieren mit `git pull` im selben Ordner; `db.env` bleibt dabei
unberührt, weil sie nicht versioniert ist.

## 2. Einrichten (auf dem Unraid-Server)

```bash
cd /mnt/user/Software/Repositories/resourcespace
./einrichten.sh
```

Legt `db.env` mit Zufallspasswörtern an, die Datenordner und eine leere
`config.php`, und gibt `filestore/` und `config/` an `www-data` (UID 33).

## 3. Bauen und starten

```bash
docker compose up --build -d
docker compose ps
```

Der Bau holt ResourceSpace 11.0 per SVN und dauert einige Minuten. Beide
Container müssen `running` sein, MariaDB `healthy`.

## 4. Einrichtungsseite

`http://<unraid>:8088` öffnen. Die Werte:

| Feld | Eintrag |
|---|---|
| MySQL-Server | **`mariadb`** (nicht `localhost`) |
| Benutzername | `resourcespace_rw` |
| Passwort | `MYSQL_PASSWORD` aus `db.env` (`grep MYSQL_PASSWORD db.env`) |
| Datenbankname | `resourcespace` |
| MySQL-Binary-Pfad | **leer lassen** |
| Basis-URL | `http://<unraid>:8088` |

Danach steht die Konfiguration in `/mnt/user/appdata/resourcespace/config/config.php`.

**E-Mail:** Postfix ist im Abbild installiert, wird aber nicht gestartet. Für
Mails (Passwort vergessen, Benachrichtigungen) in der Einrichtung bzw. später in
`config.php` einen SMTP-Server eintragen.

## Sichern

Die Rohdateien unter `mariadb/` sind bei laufendem Container nicht konsistent.
Vor der Appdata-Sicherung einen Dump ziehen:

```bash
docker exec resourcespace-mariadb sh -c 'mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" resourcespace' | gzip > /mnt/user/appdata/resourcespace/db-dump.sql.gz
```

`db.env` gehört ebenfalls in die Sicherung — ohne das Root-Passwort ist die
Datenbank nur mit Umwegen zu öffnen.

## Aktualisieren

- **MariaDB:** Tag in `compose.yaml` bewusst ändern, vorher Dump ziehen.
- **ResourceSpace:** das `Dockerfile` checkt `releases/11.0` aus. Neu bauen holt
  den neuesten 11.0-Stand: `docker compose build --no-cache resourcespace && docker compose up -d`.
  Für eine neue Hauptversion die Zeile `svn co ... releases/11.0` anpassen.

## Hinweise

- **Uploadgrenze** ist im Abbild auf 100 MB gesetzt (`upload_max_filesize`,
  `post_max_size` im `Dockerfile`). Für große Videos dort erhöhen und neu bauen.
- **Keine Portfreigabe** ins Internet ohne vorgeschalteten Reverse Proxy mit TLS.
- MariaDB läuft zuverlässiger, wenn `appdata` auf dem Cache-Pool liegt
  (Share-Einstellung „Primary storage: Cache", kein Mover aufs Array).

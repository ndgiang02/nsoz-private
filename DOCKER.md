# Docker run guide

## Start server

```powershell
docker compose up --build
```

Server listens on TCP `14444` on the host machine. A game client running on the same PC should connect to `127.0.0.1:14444`. A client on another device in the LAN should connect to this PC's LAN IP and port `14444`.

## Manage database

phpMyAdmin is available at:

```text
http://127.0.0.1:8081
```

Default database login:

```text
Server: db
Username: nsoz
Password: nsoz_password
Database: nsoz2
```

Root login is also available if needed:

```text
Server: db
Username: root
Password: root_password
```

## Reset imported database

The SQL dump is only imported the first time the MariaDB volume is created. To re-import from `database/database.sql`:

```powershell
docker compose down -v
docker compose up --build
```

## Notes

- The server container writes `config.properties` at startup from environment variables.
- The server image builds the runnable JAR from `pom.xml` and `src/` during `docker compose build`; no local `target/` folder or prebuilt JAR is required after cloning.
- `Nso.jar` in this folder does not declare a `Main-Class` and contains `com.nsoz` server classes, so it does not look like a runnable desktop client JAR from the files present here.
- Socket.IO is configured to `ws://127.0.0.1:8020` by default because no websocket service is included in this project. The server logs may show a websocket connection failure, but the TCP game server can still listen on `14444` if the rest of startup succeeds.

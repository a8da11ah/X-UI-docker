# x-ui-pro in Docker

Wraps [GFW4Fun/x-ui-pro](https://github.com/GFW4Fun/x-ui-pro) — a shell script that
provisions nginx, an X-UI panel, v2rayA, WARP+, Tor and cron jobs onto a bare
Linux host via `systemctl`/`crontab`/`apt` — into a single container.

## Why this isn't a normal Dockerfile

`x-ui-pro.sh` assumes it's running on a real, booted VPS: it enables systemd
services, edits `/etc/resolv.conf`, and drives `crontab`. So this image runs
**systemd as PID 1** (like a lightweight VM) and a one-shot systemd unit
(`x-ui-pro-install.service`) runs the real installer script on first boot,
exactly as it would run on a fresh VPS. That means the container needs
`privileged: true` and a real cgroup mount — it is not a sandboxed, minimal
container the way most Dockerized apps are.

## Before you start

1. **Point DNS at this host first.** The installer requests a real Let's
   Encrypt certificate via `certbot --standalone` on ports 80/443 during
   first boot. If `SUBDOMAIN` doesn't already resolve to this host's public
   IP, that step will fail.
2. Copy `.env.example` to `.env` and fill in your domain and options:
   ```
   cp .env.example .env
   ```

## Run it

```
docker compose up -d --build
```

Watch the first-boot install (it runs once, takes several minutes — full
`apt` installs, nginx, tor, v2rayA, warp-plus, certbot):

```
docker exec -it x-ui-pro journalctl -u x-ui-pro-install.service -f
```

## Finding your panel URL and credentials

`x-ui-pro.sh` generates a random internal panel port and admin credentials
on first install and prints them to the installer log (see command above).
You don't need to publish that random port yourself — nginx reverse-proxies
the panel, v2rayA, and the subscription URL through port 443 (already
published in `docker-compose.yml`) at the path shown in the log, e.g.:

```
Admin Panel [SSL]:
XrayUI: https://<your-domain>/<random-path>/
V2rayA: https://<your-domain>/<random-path>/
Username: ...
Password: ...
```

Save that output — it's only printed once, at install time. Since it also
lands in `journalctl`/your terminal scrollback, treat those credentials as
already exposed and rotate the panel password after you've confirmed
everything works.

The `x-ui` CLI (`docker exec -it x-ui-pro x-ui settings`) may report
`Please install the panel first` even though the panel is running — the
installer's service/path layout doesn't line up with what that CLI's status
check expects for every `-panel` fork. Not blocking; use the printed
URL/credentials above instead. If you want to chase it down, check
`docker exec -it x-ui-pro systemctl status x-ui` and
`docker exec -it x-ui-pro systemctl list-units --type=service` to see what
the panel's actual service is named inside the container.

## Persistence

Named volumes back everything the installer writes, so `docker compose down`
(without `-v`) keeps your panel config, certs, nginx config, and backups
across restarts/rebuilds:

- `x-ui-etc` — `/etc/x-ui` (panel DB, config)
- `letsencrypt` — `/etc/letsencrypt` (SSL certs)
- `nginx-etc` — `/etc/nginx`
- `backups` — `/var/backups` (daily X-UI DB backups the script schedules)
- `tor-etc`, `cron-spool`, `x-ui-pro-state` (`.installed` marker)

## Known limitations vs. a real VPS install

- **UFW/iptables is left off by default** (`UFW=` empty in `.env`). Docker
  already restricts the host to whatever you publish under `ports:` in
  `docker-compose.yml`; running UFW inside the container as well fights with
  Docker's own netfilter rules and can break container networking.
- **Psiphon isn't wired up** by the upstream script's CLI flags the same way
  WARP/Tor are — if you need it, check the script's interactive prompts via
  the journal log above.
- This uses the `--privileged` + `cgroup: host` systemd-in-Docker pattern.
  It's the closest match to "run this installer unmodified," but it's a
  heavier container than idiomatic Docker apps — effectively a lightweight
  VM. If you outgrow this and want proper per-service isolation, splitting
  nginx / x-ui / v2rayA / warp-plus into separate containers is the next
  step, but it's a real rewrite, not a wrapper.

## Uninstall / reset

```
docker compose down -v   # removes containers AND all persisted data
```

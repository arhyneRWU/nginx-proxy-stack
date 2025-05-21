# nginx-proxy-stack
A Dockerized, template‑driven Nginx reverse‑proxy boilerplate featuring integrated BotBlocker and Let’s Encrypt support, dynamic Jinja2‑powered site configuration, and a single deploy script for both test and production environments.
~~~~
~~~~
- **Automatic** Jinja2‑based site config generation
- **BotBlocker** & DDOS protection
- **Let’s Encrypt** support via Certbot (with dummy certs for local development)
- A single **deploy.sh** script for test vs production workflows
-  **dynamic DNS resolution** for upstreams

------

## Features

- **Multi‑domain support** with per‑site upload limits and HTTPS enforcement
- **force_https** flag to redirect all HTTP → HTTPS (while still serving ACME challenges)
- **BotBlocker integration** (Yandex/nginx‑blocker) for bad‑bot blacklisting
- **Dynamic upstream resolution** (resolve hostnames at request time)
- **Single deploy script**:
  - `./scripts/deploy.sh` (test mode by default)
  - `./scripts/deploy.sh --prod` for production
- **Cron job installer** to update blocker rules twice daily

------

## Prerequisites

- Docker Engine & Docker Compose v2+
- Python 3.9+
- Administrator access to edit `/etc/hosts`
- Tested on macOS and Linux

------

## Directory Structure

```
.
├── Dockerfile                     # Builds the proxy image
├── botblocker/                    # Yandex/nginx-blocker repo + overrides
├── certbot/                       # ACME webroot & cert tree
│   ├── conf/…                     # Let's Encrypt live files
│   └── www/…                      # ACME challenge files
├── config/
│   ├── domains.yml                # Site definitions :contentReference[oaicite:0]{index=0}:contentReference[oaicite:1]{index=1}
│   └── templates/
│       └── site.conf.j2           # Jinja2 template :contentReference[oaicite:2]{index=2}:contentReference[oaicite:3]{index=3}
├── docker-compose.test.yml        # Local/dev stack
├── docker-compose.yml             # Production stack
├── nginx/
│   ├── nginx.conf                 # Main config (add `resolver` here)
│   ├── conf.d/…                   # Static includes
│   ├── snippets/…                 # Reusable snippets
│   └── sites-enabled/             # Generated configs
├── nginx-logs/                    # Mounted logs (for logrotate)
└── scripts/
    ├── blocker/
    │   └── update-blocker.sh      # Pull & reload rules
    ├── certs/
    │   └── generate-dummy-certs.sh
    ├── config/
    │   └── generate-configs.py   
    ├── cron/
    │   └── install-cron-jobs.sh
    ├── maintenance/
    │   └── logrotate/
    │       ├── logrotate.conf
    │       └── logrotate.state
    └── deploy.sh                  # Test/prod deploy orchestrator
```

------

## Configuration

### 1. Define Sites (`config/domains.yml`)

```
sites:
  hello1:
    hostnames: [hello1.local]
    upstream:
      name: hello1_backend
      servers:
        - host: hello1
          port: 8000
    client_max_body_size: 1M
    force_https: false

  hello2:
    hostnames: [hello2.local]
    upstream:
      name: hello2_backend
      servers:
        - host: hello2
          port: 8000
    client_max_body_size: 1M
    force_https: true
```

- `force_https: true` → HTTP → HTTPS redirect (301) for all non‑ACME traffic.

### 2. Jinja2 Template (`config/templates/site.conf.j2`)

- Upstream with dynamic resolve & shared zone:

  ```
  upstream {{ upstream.name }} {
      zone {{ upstream.name }} 64k;
  {% for srv in upstream.servers %}
      server {{ srv.host }}:{{ srv.port }} resolve;
  {% endfor %}
  }
  ```

- Conditional HTTP block for redirects or proxying.

------

## Deploy Script

```
./scripts/deploy.sh        # Test mode (docker-compose.test.yml)
./scripts/deploy.sh --prod # Production (docker-compose.yml + cron install)
```

What it does:

1. Ensures `webnet` network exists
2. Activates virtualenv & installs Jinja2/PyYAML
3. Renders `site.conf.j2` → `nginx/sites-enabled`
4. Generates dummy certs only if missing
5. Tears down and brings up proxy container
6. (Prod) Installs cron job for blocker updates
7. Rotates logs via project‑local config

------

## Dynamic DNS Resolution (Optional)

In `nginx/nginx.conf` inside `http { … }`, add:

```
resolver 127.0.0.11 valid=30s ipv6=off;
```

Combined with `resolve` in your `upstream` blocks, Nginx will lookup hostnames at request time, so you can deploy new vhosts before their containers exist.

------

## BotBlocker Updates

Pull new rules twice daily via cron:

```
./scripts/cron/install-cron-jobs.sh
```

Manually update at any time:

```
./scripts/blocker/update-blocker.sh
```

------

## Log Rotation

Run local logrotate once:

```
bash scripts/maintenance/run-logrotate.sh
```

Cron‑schedule in `install-cron-jobs.sh` can include this step if desired.

------

## Adding New Services

1. Create a service directory (e.g. `services/api/`) with its own `Dockerfile` and `docker-compose.yml` referencing `webnet` (external).
2. Add its host/service mapping in `config/domains.yml`.
3. Re-run `./scripts/deploy.sh` (or manual generate + reload) — it “just works.”

------

## Troubleshooting

- **Upstream “host not found”**: ensure service and proxy share `webnet`.

- **`nginx -t` errors on missing host**: enable dynamic DNS (see above).

- **Hosts file**: add `hello1.local`, `hello2.local` to `/etc/hosts → 127.0.0.1`.

- **DNS caching on macOS**:

  ```
  sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
  ```

------


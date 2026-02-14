# Hetzner VPS deploy (quick test)

This deploy setup uses Docker, Postgres, and Caddy for TLS.

## 1) Prepare web build on your machine

Update the API base URL:

- Edit frontend/assets/config.json and set "baseUrl" to:
  - https://api.<server-ip>.nip.io

Then build the web bundle:

- flutter build web --release

## 2) Upload repo to the VPS

- Copy the whole repo to /opt/music-school-app on the server.

## 3) Create environment file

- Copy deploy/.env.example to deploy/.env
- Fill in secrets and set APP_HOST/API_HOST to your nip.io hostnames.

Example for server IP 203.0.113.10:
- APP_HOST=app.203-0-113-10.nip.io
- API_HOST=api.203-0-113-10.nip.io

## 4) Start the stack

From the repo root on the VPS:

- docker compose -f deploy/docker-compose.prod.yml up -d --build

## 5) Verify

- https://app.<server-ip>.nip.io
- https://api.<server-ip>.nip.io/health (if you have a health endpoint)

## 6) When real subdomains are ready

- Update APP_HOST and API_HOST in deploy/.env
- Re-run docker compose

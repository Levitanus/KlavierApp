# Music School App

Monorepo for the Musikschule am Thomas-Mann-Platz application.

Structure:
- `backend/` — Rust + actix-web API
- `frontend/` — Flutter mobile app
- `docker-compose.yml` — Postgres services for prod and test

To finish setup locally:

1. Install Rust and Cargo.
2. (Optional) Install Flutter and run `flutter create frontend`.
3. Start databases: `docker compose up -d`.

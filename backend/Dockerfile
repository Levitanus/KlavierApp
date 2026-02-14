FROM rust:1.95-bookworm AS builder

WORKDIR /app

COPY Cargo.toml ./
COPY migrations ./migrations
COPY src ./src

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/music_school_app_backend /usr/local/bin/music_school_app_backend

ENV RUST_LOG=info
EXPOSE 8080

CMD ["/usr/local/bin/music_school_app_backend"]

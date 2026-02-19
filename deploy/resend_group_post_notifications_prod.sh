#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Resend feed post notification (and push) to all group participants for one post (production wrapper).

This script reads recipients directly from the running Postgres container via docker compose,
then calls POST /api/notifications for each recipient.

Usage:
  resend_group_post_notifications_prod.sh --post-id <id> [--api-base <url>] [--compose-file <path>] [--env-file <path>] [--dry-run]

Arguments:
  --post-id       feed_posts.id to resend notifications for (required)
  --api-base      Backend base URL; if omitted uses API_BASE_URL or API_HOST from env file
  --compose-file  Path to docker-compose.prod.yml (default: deploy/docker-compose.prod.yml)
  --env-file      Env file for compose and defaults (default: <compose-dir>/.env)
  --dry-run       Print payloads only, do not call API

Environment:
  AUTH_TOKEN      Optional JWT token; if set, sent as Authorization: Bearer <token>
EOF
}

read_env_value() {
  local key="$1"
  local file="$2"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  local line
  line=$(grep -E "^[[:space:]]*${key}=" "$file" | tail -n 1 || true)
  if [[ -z "$line" ]]; then
    return 0
  fi

  line="${line#*=}"
  line="${line%\"}"
  line="${line#\"}"
  line="${line%\'}"
  line="${line#\'}"
  printf '%s' "$line"
}

POST_ID=""
API_BASE=""
COMPOSE_FILE="deploy/docker-compose.prod.yml"
ENV_FILE=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --post-id)
      POST_ID="${2:-}"
      shift 2
      ;;
    --api-base)
      API_BASE="${2:-}"
      shift 2
      ;;
    --compose-file)
      COMPOSE_FILE="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$POST_ID" ]]; then
  echo "--post-id is required" >&2
  usage
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

if [[ -z "$ENV_FILE" ]]; then
  COMPOSE_DIR="$(cd "$(dirname "$COMPOSE_FILE")" && pwd)"
  ENV_FILE="$COMPOSE_DIR/.env"
fi

API_BASE_URL_ENV="$(read_env_value "API_BASE_URL" "$ENV_FILE")"
API_HOST_ENV="$(read_env_value "API_HOST" "$ENV_FILE")"
POSTGRES_USER_ENV="$(read_env_value "POSTGRES_USER" "$ENV_FILE")"
POSTGRES_DB_ENV="$(read_env_value "POSTGRES_DB" "$ENV_FILE")"

if [[ -z "$API_BASE" ]]; then
  if [[ -n "$API_BASE_URL_ENV" ]]; then
    API_BASE="$API_BASE_URL_ENV"
  elif [[ -n "$API_HOST_ENV" ]]; then
    API_BASE="https://${API_HOST_ENV}"
  fi
fi

if [[ -z "$API_BASE" ]]; then
  echo "--api-base is required (or define API_BASE_URL/API_HOST in $ENV_FILE)" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not found in PATH" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not found in PATH" >&2
  exit 1
fi

API_BASE="${API_BASE%/}"
POSTGRES_USER="${POSTGRES_USER_ENV:-music_school}"
POSTGRES_DB="${POSTGRES_DB_ENV:-music_school}"

COMPOSE_CMD=(docker compose -f "$COMPOSE_FILE")
if [[ -f "$ENV_FILE" ]]; then
  COMPOSE_CMD=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE")
fi

DB_CONTAINER_ID="$(${COMPOSE_CMD[@]} ps -q db)"
if [[ -z "$DB_CONTAINER_ID" ]]; then
  echo "db service is not running. Start stack first: docker compose -f $COMPOSE_FILE up -d" >&2
  exit 1
fi

TMP_SQL_EXISTS="$(mktemp)"
TMP_SQL_PAYLOADS="$(mktemp)"
cleanup() {
  rm -f "$TMP_SQL_EXISTS" "$TMP_SQL_PAYLOADS"
}
trap cleanup EXIT

cat > "$TMP_SQL_EXISTS" <<'SQL'
SELECT EXISTS(
  SELECT 1
  FROM feed_posts p
  JOIN feeds f ON f.id = p.feed_id
  WHERE p.id = :'post_id'
    AND f.owner_type = 'group'
);
SQL

POST_EXISTS=$(cat "$TMP_SQL_EXISTS" | ${COMPOSE_CMD[@]} exec -T db psql -X -v ON_ERROR_STOP=1 -t -A -v post_id="$POST_ID" -U "$POSTGRES_USER" -d "$POSTGRES_DB")

if [[ "$POST_EXISTS" != "t" ]]; then
  echo "Post $POST_ID was not found in a group feed. Nothing to send." >&2
  exit 1
fi

cat > "$TMP_SQL_PAYLOADS" <<'SQL'
WITH post_ctx AS (
  SELECT
    p.id AS post_id,
    p.feed_id,
    p.author_user_id,
    p.title AS post_title,
    p.is_important,
    f.title AS feed_title,
    f.owner_group_id AS group_id
  FROM feed_posts p
  JOIN feeds f ON f.id = p.feed_id
  WHERE p.id = :'post_id'
    AND f.owner_type = 'group'
),
recipients AS (
  SELECT DISTINCT participants.user_id, pc.*
  FROM post_ctx pc
  JOIN LATERAL (
    SELECT sg.teacher_user_id AS user_id
    FROM student_groups sg
    JOIN teachers t ON t.user_id = sg.teacher_user_id
    WHERE sg.id = pc.group_id
      AND sg.status = 'active'
      AND t.status = 'active'

    UNION

    SELECT gsr.student_user_id AS user_id
    FROM group_student_relations gsr
    JOIN student_groups sg ON sg.id = gsr.group_id
    JOIN students s ON s.user_id = gsr.student_user_id
    WHERE gsr.group_id = pc.group_id
      AND sg.status = 'active'
      AND s.status = 'active'

    UNION

    SELECT psr.parent_user_id AS user_id
    FROM group_student_relations gsr
    JOIN student_groups sg ON sg.id = gsr.group_id
    JOIN students s ON s.user_id = gsr.student_user_id
    JOIN parent_student_relations psr ON psr.student_user_id = gsr.student_user_id
    JOIN parents p ON p.user_id = psr.parent_user_id
    WHERE gsr.group_id = pc.group_id
      AND sg.status = 'active'
      AND s.status = 'active'
      AND p.status = 'active'
  ) participants ON TRUE
  LEFT JOIN feed_user_settings fus
    ON fus.feed_id = pc.feed_id
   AND fus.user_id = participants.user_id
  WHERE participants.user_id <> pc.author_user_id
    AND COALESCE(fus.notify_new_posts, TRUE) = TRUE
)
SELECT json_build_object(
  'user_id', user_id,
  'type', 'feed_post',
  'title', format('New post in %s', trim(feed_title)),
  'priority', CASE WHEN is_important THEN 'high' ELSE 'normal' END,
  'body', json_build_object(
    'type', 'feed_post',
    'title', format('New post in %s', trim(feed_title)),
    'route', '/feeds',
    'content', json_build_object(
      'blocks', json_build_array(
        json_build_object(
          'type', 'text',
          'text', format('New post in %s:', trim(feed_title)),
          'style', 'body'
        ),
        json_build_object(
          'type', 'text',
          'text', COALESCE(NULLIF(trim(post_title), ''), 'Untitled post'),
          'style', 'title'
        )
      ),
      'actions', json_build_array(
        json_build_object(
          'label', 'Open Feeds',
          'route', '/feeds',
          'action', NULL,
          'primary', TRUE,
          'icon', 'dynamic_feed'
        )
      )
    ),
    'metadata', json_build_object(
      'feed_id', feed_id,
      'post_id', post_id
    )
  )
)::text
FROM recipients
ORDER BY user_id;
SQL

readarray -t PAYLOADS < <(cat "$TMP_SQL_PAYLOADS" | ${COMPOSE_CMD[@]} exec -T db psql -X -v ON_ERROR_STOP=1 -t -A -v post_id="$POST_ID" -U "$POSTGRES_USER" -d "$POSTGRES_DB")

COUNT="${#PAYLOADS[@]}"
if [[ "$COUNT" -eq 0 ]]; then
  echo "No recipients resolved for post $POST_ID."
  exit 0
fi

echo "Resolved $COUNT recipient(s) for post $POST_ID."

echo "API base: $API_BASE"
if [[ "$DRY_RUN" == "true" ]]; then
  printf '%s\n' "${PAYLOADS[@]}"
  echo "Dry run complete."
  exit 0
fi

CURL_HEADERS=( -H "Content-Type: application/json" )
if [[ -n "${AUTH_TOKEN:-}" ]]; then
  CURL_HEADERS+=( -H "Authorization: Bearer ${AUTH_TOKEN}" )
fi

SENT=0
FAILED=0

for payload in "${PAYLOADS[@]}"; do
  RESPONSE=$(curl -sS -w "\n%{http_code}" -X POST "${API_BASE}/api/notifications" "${CURL_HEADERS[@]}" --data "$payload")
  HTTP_CODE="${RESPONSE##*$'\n'}"
  BODY="${RESPONSE%$'\n'*}"

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    SENT=$((SENT + 1))
  else
    FAILED=$((FAILED + 1))
    echo "Failed notification (HTTP $HTTP_CODE): $BODY" >&2
  fi
done

echo "Done. Sent: $SENT, Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 2
fi

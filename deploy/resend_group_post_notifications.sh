#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Resend feed post notification (and push) to all group participants for one post.

Usage:
  resend_group_post_notifications.sh --post-id <id> --api-base <url> [--database-url <url>] [--dry-run]

Arguments:
  --post-id        feed_posts.id to resend notifications for (required)
  --api-base       Backend base URL, e.g. https://api.example.com (required)
  --database-url   Postgres connection URL (optional if DATABASE_URL env is set)
  --dry-run        Print payloads only, do not call API

Environment:
  DATABASE_URL     Used when --database-url is not passed
  AUTH_TOKEN       Optional JWT token; if set, sent as Authorization: Bearer <token>
EOF
}

POST_ID=""
API_BASE=""
DATABASE_URL_ARG=""
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
    --database-url)
      DATABASE_URL_ARG="${2:-}"
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

if [[ -z "$POST_ID" || -z "$API_BASE" ]]; then
  echo "--post-id and --api-base are required" >&2
  usage
  exit 1
fi

DATABASE_URL="${DATABASE_URL_ARG:-${DATABASE_URL:-}}"
if [[ -z "$DATABASE_URL" ]]; then
  echo "Database URL is required: pass --database-url or set DATABASE_URL" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required but not found in PATH" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not found in PATH" >&2
  exit 1
fi

API_BASE="${API_BASE%/}"

POST_EXISTS=$(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -t -A -v post_id="$POST_ID" <<'SQL'
SELECT EXISTS(
  SELECT 1
  FROM feed_posts p
  JOIN feeds f ON f.id = p.feed_id
  WHERE p.id = :'post_id'
    AND f.owner_type = 'group'
);
SQL
)

if [[ "$POST_EXISTS" != "t" ]]; then
  echo "Post $POST_ID was not found in a group feed. Nothing to send." >&2
  exit 1
fi

readarray -t PAYLOADS < <(psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -t -A -v post_id="$POST_ID" <<'SQL'
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
)

COUNT="${#PAYLOADS[@]}"
if [[ "$COUNT" -eq 0 ]]; then
  echo "No recipients resolved for post $POST_ID."
  exit 0
fi

echo "Resolved $COUNT recipient(s) for post $POST_ID."

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

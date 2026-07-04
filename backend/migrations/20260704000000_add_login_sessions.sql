CREATE TABLE IF NOT EXISTS login_sessions (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_login_sessions_user_id ON login_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_login_sessions_last_used_at ON login_sessions(last_used_at);
CREATE INDEX IF NOT EXISTS idx_login_sessions_revoked_at ON login_sessions(revoked_at) WHERE revoked_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_login_sessions_active_user_last_used
ON login_sessions(user_id, last_used_at DESC)
WHERE revoked_at IS NULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
        CREATE EXTENSION IF NOT EXISTS pg_cron;

        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'cron' AND table_name = 'job') THEN
            PERFORM cron.unschedule(jobid)
            FROM cron.job
            WHERE jobname = 'cleanup_login_sessions';

            PERFORM cron.schedule(
                'cleanup_login_sessions',
                '0 3 * * *',
                $job$
                DELETE FROM login_sessions
                WHERE (revoked_at IS NOT NULL AND revoked_at <= NOW() - INTERVAL '30 days')
                   OR (last_used_at <= NOW() - INTERVAL '90 days')
                $job$
            );
        END IF;
    END IF;
END $$;
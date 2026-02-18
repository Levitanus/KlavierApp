CREATE INDEX IF NOT EXISTS idx_notifications_read_at
ON notifications (read_at)
WHERE read_at IS NOT NULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
        CREATE EXTENSION IF NOT EXISTS pg_cron;

        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'cron' AND table_name = 'job') THEN
            PERFORM cron.unschedule(jobid)
            FROM cron.job
            WHERE jobname = 'cleanup_read_notifications_older_than_2_days';

            PERFORM cron.schedule(
                'cleanup_read_notifications_older_than_2_days',
                '0 */6 * * *',
                                $job$
                DELETE FROM notifications
                WHERE read_at IS NOT NULL
                  AND read_at <= NOW() - INTERVAL '2 days'
                                $job$
            );
        END IF;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'hometask_type'
          AND e.enumlabel = 'free_answer'
    ) THEN
        ALTER TYPE hometask_type ADD VALUE 'free_answer';
    END IF;
END$$;

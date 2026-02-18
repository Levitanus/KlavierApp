CREATE TABLE IF NOT EXISTS student_groups (
    id SERIAL PRIMARY KEY,
    teacher_user_id INTEGER NOT NULL REFERENCES teachers(user_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE student_groups
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

ALTER TABLE student_groups
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

ALTER TABLE student_groups DROP CONSTRAINT IF EXISTS student_groups_status_check;
ALTER TABLE student_groups
    ADD CONSTRAINT student_groups_status_check CHECK (status IN ('active', 'archived'));

CREATE TABLE IF NOT EXISTS group_student_relations (
    group_id INTEGER NOT NULL REFERENCES student_groups(id) ON DELETE CASCADE,
    student_user_id INTEGER NOT NULL REFERENCES students(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, student_user_id)
);

CREATE INDEX IF NOT EXISTS idx_student_groups_teacher ON student_groups(teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_student_groups_status ON student_groups(status);
CREATE INDEX IF NOT EXISTS idx_group_student_group ON group_student_relations(group_id);
CREATE INDEX IF NOT EXISTS idx_group_student_student ON group_student_relations(student_user_id);

CREATE TRIGGER update_student_groups_updated_at
    BEFORE UPDATE ON student_groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

ALTER TYPE feed_owner_type ADD VALUE IF NOT EXISTS 'group';

ALTER TABLE feeds
    ADD COLUMN IF NOT EXISTS owner_group_id INTEGER REFERENCES student_groups(id) ON DELETE SET NULL;

ALTER TABLE feeds DROP CONSTRAINT IF EXISTS feeds_owner_scope_check;
ALTER TABLE feeds
    ADD CONSTRAINT feeds_owner_scope_check CHECK (
        (owner_type::text = 'school' AND owner_user_id IS NULL AND owner_group_id IS NULL)
        OR (owner_type::text = 'teacher' AND owner_group_id IS NULL)
        OR (owner_type::text = 'group' AND owner_group_id IS NOT NULL AND owner_user_id IS NULL)
    );

CREATE INDEX IF NOT EXISTS idx_feeds_owner_group ON feeds(owner_group_id);

CREATE TABLE IF NOT EXISTS group_hometask_assignments (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL REFERENCES student_groups(id) ON DELETE CASCADE,
    teacher_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    due_date TIMESTAMPTZ,
    hometask_type hometask_type NOT NULL,
    repeat_every_days INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_group_hometask_assignments_group ON group_hometask_assignments(group_id);
CREATE INDEX IF NOT EXISTS idx_group_hometask_assignments_teacher ON group_hometask_assignments(teacher_id);

CREATE TRIGGER update_group_hometask_assignments_updated_at
    BEFORE UPDATE ON group_hometask_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE hometasks
    ADD COLUMN IF NOT EXISTS group_assignment_id INTEGER REFERENCES group_hometask_assignments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_hometasks_group_assignment_id ON hometasks(group_assignment_id);

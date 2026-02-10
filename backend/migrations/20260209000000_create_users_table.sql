-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    profile_image TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create user_roles junction table (many-to-many)
CREATE TABLE IF NOT EXISTS user_roles (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

-- Create password_reset_tokens table
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ
);

-- Create password_reset_requests table (for users without email)
CREATE TABLE IF NOT EXISTS password_reset_requests (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by_admin_id INTEGER REFERENCES users(id)
);

-- Create index on token_hash for faster lookups
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token_hash ON password_reset_tokens(token_hash);

-- Create index on username for faster lookups
CREATE INDEX IF NOT EXISTS idx_password_reset_requests_username ON password_reset_requests(username);

-- Insert roles
INSERT INTO roles (name) VALUES 
    ('admin'),
    ('teacher'),
    ('parent'),
    ('student');

-- Insert initial user
-- Password: "admin" hashed with Argon2id
INSERT INTO users (username, password_hash) 
VALUES ('levitanus', '$argon2id$v=19$m=19456,t=2,p=1$b9NSOm601oo4mk6MMcRN8w$bPUHwI7KVVAAf2Myosau4KUxO28X+MJ6Q7oL4ZCU1fY');

-- Assign admin role to levitanus
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id 
FROM users u, roles r 
WHERE u.username = 'levitanus' AND r.name = 'admin';

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- e.g., 'task_assigned', 'password_issued', 'schedule_change', 'results_available'
    title TEXT NOT NULL,
    body JSONB NOT NULL, -- Rich content structure
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ, -- NULL if unread
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent'))
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_read_at ON notifications(read_at) WHERE read_at IS NULL; -- Index only unread
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, read_at) WHERE read_at IS NULL;

-- GIN index for JSONB queries (for searching within notification body)
CREATE INDEX IF NOT EXISTS idx_notifications_body_gin ON notifications USING gin(body);

-- ============================================================================
-- Role-Specific Tables (Students, Parents, Teachers)
-- ============================================================================

-- Create students table with additional details
CREATE TABLE IF NOT EXISTS students (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    address TEXT NOT NULL,
    birthday DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create parents table with additional details
CREATE TABLE IF NOT EXISTS parents (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create teachers table with additional details
CREATE TABLE IF NOT EXISTS teachers (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create parent-student relationship table (many-to-many)
CREATE TABLE IF NOT EXISTS parent_student_relations (
    parent_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    student_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (parent_user_id, student_user_id),
    -- Ensure both users have the appropriate roles
    CONSTRAINT fk_parent FOREIGN KEY (parent_user_id) REFERENCES parents(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_student FOREIGN KEY (student_user_id) REFERENCES students(user_id) ON DELETE CASCADE,
    -- Prevent self-parenting
    CONSTRAINT no_self_parenting CHECK (parent_user_id != student_user_id)
);

-- Create registration tokens table
CREATE TABLE IF NOT EXISTS registration_tokens (
    id SERIAL PRIMARY KEY,
    token_hash TEXT NOT NULL UNIQUE,
    created_by_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('student', 'parent', 'teacher')),
    -- For parent registration from student profile
    related_student_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    used_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for role tables
CREATE INDEX IF NOT EXISTS idx_students_full_name ON students(full_name);
CREATE INDEX IF NOT EXISTS idx_parents_full_name ON parents(full_name);
CREATE INDEX IF NOT EXISTS idx_teachers_full_name ON teachers(full_name);
CREATE INDEX IF NOT EXISTS idx_parent_student_parent ON parent_student_relations(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_parent_student_student ON parent_student_relations(student_user_id);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_hash ON registration_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_expires ON registration_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_related_student ON registration_tokens(related_student_id);

-- Trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_students_updated_at 
    BEFORE UPDATE ON students 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_parents_updated_at 
    BEFORE UPDATE ON parents 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_teachers_updated_at 
    BEFORE UPDATE ON teachers 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

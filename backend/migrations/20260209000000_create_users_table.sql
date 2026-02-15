-- Create role status enum
CREATE TYPE role_status AS ENUM ('active', 'archived');

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
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
INSERT INTO users (username, full_name, password_hash) 
VALUES ('levitanus', 'Timofei Kazantsev', '$argon2id$v=19$m=19456,t=2,p=1$b9NSOm601oo4mk6MMcRN8w$bPUHwI7KVVAAf2Myosau4KUxO28X+MJ6Q7oL4ZCU1fY');

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
    birthday DATE NOT NULL,
    status role_status NOT NULL DEFAULT 'active',
    archived_at TIMESTAMPTZ,
    archived_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create parents table with additional details
CREATE TABLE IF NOT EXISTS parents (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    status role_status NOT NULL DEFAULT 'active',
    archived_at TIMESTAMPTZ,
    archived_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create teachers table with additional details
CREATE TABLE IF NOT EXISTS teachers (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    status role_status NOT NULL DEFAULT 'active',
    archived_at TIMESTAMPTZ,
    archived_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
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
    -- For student registration from teacher profile
    related_teacher_id INTEGER REFERENCES teachers(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    used_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL
);

-- Create teacher-student relationship table (many-to-many)
CREATE TABLE IF NOT EXISTS teacher_student_relations (
    teacher_user_id INTEGER NOT NULL REFERENCES teachers(user_id) ON DELETE CASCADE,
    student_user_id INTEGER NOT NULL REFERENCES students(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (teacher_user_id, student_user_id),
    CONSTRAINT no_self_teacher_student CHECK (teacher_user_id != student_user_id)
);

-- Create indexes for role tables
CREATE INDEX IF NOT EXISTS idx_users_full_name ON users(full_name);
CREATE INDEX IF NOT EXISTS idx_students_status ON students(status);
CREATE INDEX IF NOT EXISTS idx_students_archived_at ON students(archived_at);
CREATE INDEX IF NOT EXISTS idx_parents_status ON parents(status);
CREATE INDEX IF NOT EXISTS idx_parents_archived_at ON parents(archived_at);
CREATE INDEX IF NOT EXISTS idx_teachers_status ON teachers(status);
CREATE INDEX IF NOT EXISTS idx_teachers_archived_at ON teachers(archived_at);
CREATE INDEX IF NOT EXISTS idx_parent_student_parent ON parent_student_relations(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_parent_student_student ON parent_student_relations(student_user_id);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_hash ON registration_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_expires ON registration_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_related_student ON registration_tokens(related_student_id);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_related_teacher ON registration_tokens(related_teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_student_teacher ON teacher_student_relations(teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_student_student ON teacher_student_relations(student_user_id);

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

-- ============================================================================
-- Hometask System Tables
-- ============================================================================

-- Create hometask status enum
CREATE TYPE hometask_status AS ENUM ('assigned', 'completed_by_student', 'accomplished_by_teacher');

-- Create hometask type enum
CREATE TYPE hometask_type AS ENUM ('checklist', 'progress', 'simple');

-- Create hometasks table
CREATE TABLE IF NOT EXISTS hometasks (
    id SERIAL PRIMARY KEY,
    teacher_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status hometask_status NOT NULL DEFAULT 'assigned',
    due_date TIMESTAMPTZ,
    repeat_every_days INTEGER,
    next_reset_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sort_order INTEGER NOT NULL DEFAULT 0,
    hometask_type hometask_type NOT NULL,
    content_id INTEGER
);

-- Create hometask_checklists table
CREATE TABLE IF NOT EXISTS hometask_checklists (
    id SERIAL PRIMARY KEY,
    items JSONB NOT NULL
);

-- Create submission type enum
CREATE TYPE submission_type AS ENUM ('photo', 'text');

-- Create hometask_submissions table
CREATE TABLE IF NOT EXISTS hometask_submissions (
    id SERIAL PRIMARY KEY,
    hometask_id INTEGER NOT NULL REFERENCES hometasks(id) ON DELETE CASCADE,
    student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    submission_type submission_type NOT NULL,
    content TEXT NOT NULL, -- URL for photo, text for text
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for hometask tables
CREATE INDEX IF NOT EXISTS idx_hometasks_teacher_id ON hometasks(teacher_id);
CREATE INDEX IF NOT EXISTS idx_hometasks_student_id ON hometasks(student_id);
CREATE INDEX IF NOT EXISTS idx_hometasks_status ON hometasks(status);
CREATE INDEX IF NOT EXISTS idx_hometasks_next_reset_at ON hometasks(next_reset_at);
CREATE INDEX IF NOT EXISTS idx_hometask_submissions_hometask_id ON hometask_submissions(hometask_id);
CREATE INDEX IF NOT EXISTS idx_hometask_submissions_student_id ON hometask_submissions(student_id);

-- Trigger for hometasks updated_at
CREATE TRIGGER update_hometasks_updated_at
    BEFORE UPDATE ON hometasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Media Storage (General)
-- ============================================================================

CREATE TYPE media_type AS ENUM ('image', 'audio', 'video', 'file');

CREATE TABLE IF NOT EXISTS media_files (
    id SERIAL PRIMARY KEY,
    storage_key TEXT NOT NULL UNIQUE,
    public_url TEXT NOT NULL,
    media_type media_type NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    created_by_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_files_created_by ON media_files(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_media_files_type ON media_files(media_type);

-- ============================================================================
-- Chat System
-- ============================================================================

-- Create message delivery state enum
CREATE TYPE chat_message_state AS ENUM ('sent', 'delivered', 'read');

-- Create chat_threads table
-- For peer-to-peer chats: participant_a_id and participant_b_id are the two users
-- For admin chats: participant_a_id is the user, participant_b_id is NULL (admin is abstract concept)
CREATE TABLE IF NOT EXISTS chat_threads (
    id SERIAL PRIMARY KEY,
    participant_a_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    participant_b_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    is_admin_chat BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Ensure admin chats have participant_b_id as NULL
    CONSTRAINT admin_chat_no_participant_b CHECK (
        (is_admin_chat = FALSE AND participant_b_id IS NOT NULL) OR
        (is_admin_chat = TRUE AND participant_b_id IS NULL)
    ),
    -- Ensure no self-messaging in peer chats
    CONSTRAINT no_self_peer_chat CHECK (
        (is_admin_chat = TRUE) OR (participant_a_id != participant_b_id)
    )
);

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS chat_messages (
    id SERIAL PRIMARY KEY,
    thread_id INTEGER NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
    sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body JSONB NOT NULL, -- Quill document JSON
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create attachment type enum for chat messages
CREATE TYPE chat_attachment_type AS ENUM ('image', 'audio', 'voice', 'video', 'file');

-- Create chat_message_attachments table
CREATE TABLE IF NOT EXISTS chat_message_attachments (
    id SERIAL PRIMARY KEY,
    message_id INTEGER NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    media_id INTEGER NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    attachment_type chat_attachment_type NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create message_receipts table for 3-state delivery tracking
CREATE TABLE IF NOT EXISTS message_receipts (
    id SERIAL PRIMARY KEY,
    message_id INTEGER NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    state chat_message_state NOT NULL DEFAULT 'sent',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (message_id, recipient_id)
);

-- Create chat_presence table for online/offline status
CREATE TABLE IF NOT EXISTS chat_presence (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    is_online BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for chat tables
CREATE INDEX IF NOT EXISTS idx_chat_threads_participant_a ON chat_threads(participant_a_id);
CREATE INDEX IF NOT EXISTS idx_chat_threads_participant_b ON chat_threads(participant_b_id);
CREATE INDEX IF NOT EXISTS idx_chat_threads_is_admin ON chat_threads(is_admin_chat);
CREATE INDEX IF NOT EXISTS idx_chat_threads_updated_at ON chat_threads(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_thread ON chat_messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_message_attachments_message ON chat_message_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_message_receipts_message ON message_receipts(message_id);
CREATE INDEX IF NOT EXISTS idx_message_receipts_recipient ON message_receipts(recipient_id);
CREATE INDEX IF NOT EXISTS idx_message_receipts_state ON message_receipts(state);
CREATE INDEX IF NOT EXISTS idx_chat_presence_is_online ON chat_presence(is_online);

-- Trigger for chat_threads updated_at
CREATE TRIGGER update_chat_threads_updated_at
    BEFORE UPDATE ON chat_threads
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_messages_updated_at
    BEFORE UPDATE ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Feeds
-- ============================================================================

CREATE TYPE feed_owner_type AS ENUM ('school', 'teacher');

CREATE TABLE IF NOT EXISTS feeds (
    id SERIAL PRIMARY KEY,
    owner_type feed_owner_type NOT NULL,
    owner_user_id INTEGER REFERENCES teachers(user_id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO feeds (owner_type, title)
VALUES ('school', 'School Feed');

CREATE TABLE IF NOT EXISTS feed_settings (
    feed_id INTEGER PRIMARY KEY REFERENCES feeds(id) ON DELETE CASCADE,
    allow_student_posts BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO feed_settings (feed_id)
SELECT id FROM feeds WHERE owner_type = 'school'
ON CONFLICT (feed_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS feed_user_settings (
    feed_id INTEGER NOT NULL REFERENCES feeds(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    auto_subscribe_new_posts BOOLEAN NOT NULL DEFAULT TRUE,
    notify_new_posts BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (feed_id, user_id)
);

CREATE TABLE IF NOT EXISTS feed_posts (
    id SERIAL PRIMARY KEY,
    feed_id INTEGER NOT NULL REFERENCES feeds(id) ON DELETE CASCADE,
    author_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT,
    content JSONB NOT NULL,
    is_important BOOLEAN NOT NULL DEFAULT FALSE,
    important_rank INTEGER,
    allow_comments BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feed_post_media (
    post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    media_id INTEGER NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    attachment_type chat_attachment_type NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (post_id, media_id)
);

CREATE TABLE IF NOT EXISTS feed_post_subscriptions (
    post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notify_on_comments BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS feed_comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    author_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_comment_id INTEGER REFERENCES feed_comments(id) ON DELETE CASCADE,
    content JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feed_comment_media (
    comment_id INTEGER NOT NULL REFERENCES feed_comments(id) ON DELETE CASCADE,
    media_id INTEGER NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    attachment_type chat_attachment_type NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (comment_id, media_id)
);

CREATE INDEX IF NOT EXISTS idx_feeds_owner_type ON feeds(owner_type);
CREATE INDEX IF NOT EXISTS idx_feeds_owner_user ON feeds(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_feed ON feed_posts(feed_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at ON feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_posts_important ON feed_posts(feed_id, is_important);
CREATE INDEX IF NOT EXISTS idx_feed_comments_post ON feed_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_feed_comments_parent ON feed_comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_feed_post_subscriptions_user ON feed_post_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_post_media_post ON feed_post_media(post_id);
CREATE INDEX IF NOT EXISTS idx_feed_comment_media_comment ON feed_comment_media(comment_id);

CREATE TRIGGER update_feed_posts_updated_at
    BEFORE UPDATE ON feed_posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_feed_comments_updated_at
    BEFORE UPDATE ON feed_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS feed_post_reads (
    post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_feed_post_reads_user_id ON feed_post_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_post_reads_post_id ON feed_post_reads(post_id);


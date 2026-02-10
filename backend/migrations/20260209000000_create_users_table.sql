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

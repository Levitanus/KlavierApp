-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create user_roles junction table (many-to-many)
CREATE TABLE IF NOT EXISTS user_roles (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

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

-- User Service schema bootstrap for docker-compose
--
-- The .NET user-service (backend/user-service) does NOT run migrations itself --
-- it queries an existing user_service.users table. In Kubernetes/CI the table is
-- created by the external Flyway migrations under
-- database/migrations/user-service/, but docker-compose has no Flyway step, so a
-- fresh stack would fail register/login with:
--   relation "user_service.users" does not exist
--
-- This script runs in the postgres init phase (after 01-create-schemas.sql, which
-- creates the user_service schema and the user_service_user role). It mirrors
-- database/migrations/user-service/V1__Create_users_table.sql. Keep the two in
-- sync. The heavier V2 simulation seed is intentionally NOT applied here: it
-- depends on accounts_service.accounts / transactions_service.transactions, which
-- are created later by the Java services' own Flyway and do not exist at init time.

SET search_path TO user_service;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    roles VARCHAR(100) DEFAULT 'USER',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- The table is created by the postgres superuser, so grant the runtime role
-- explicit access (don't rely solely on default privileges).
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA user_service TO user_service_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA user_service TO user_service_user;

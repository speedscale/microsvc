-- The .NET user-service does not run schema migrations on startup (unlike the
-- Flyway-based Java services), so for local docker-compose its table must be
-- created at database init time. Mirrors backend/user-service/Models/User.cs.
SET search_path TO user_service;

CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    username      VARCHAR(50)  UNIQUE NOT NULL,
    email         VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    roles         VARCHAR(100) DEFAULT 'USER',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- The service connects as user_service_user; grant it the table + identity sequence
-- created above (these are owned by the init superuser, so explicit grants are needed).
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA user_service TO user_service_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA user_service TO user_service_user;

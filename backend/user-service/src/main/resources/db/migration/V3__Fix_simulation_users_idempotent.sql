-- Migration V3: Fix simulation users insertion to be idempotent
-- This addresses the unique constraint violation issue from V2
-- Safe to run even if some simulation users already exist

-- Insert missing simulation users (idempotent)
INSERT INTO users (username, email, password_hash, roles, created_at, updated_at)
SELECT 
    'sim_user_' || LPAD(generate_series::text, 3, '0') as username,
    'sim_user_' || LPAD(generate_series::text, 3, '0') || '@simulation.local' as email,
    -- BCrypt hash for 'NewUser123!' - matches what simulation client expects
    '$2a$10$7Gejer63hAKLgl/PEvESJ.CBuqHm5hvqFxU2Y4vmw1VJ6pdiEidmK' as password_hash,
    ARRAY['USER'] as roles,
    NOW() - (RANDOM() * INTERVAL '365 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '90 days') as updated_at
FROM generate_series(1, 1000)
ON CONFLICT (username) DO NOTHING;

-- Ensure index exists for better performance during simulation
CREATE INDEX IF NOT EXISTS idx_users_username_simulation ON users(username) WHERE username LIKE 'sim_user_%';

-- Ensure constraint exists for data quality
DO $$
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_simulation_user_email'
    ) THEN
        ALTER TABLE users ADD CONSTRAINT chk_simulation_user_email 
            CHECK (email ~ '^sim_user_[0-9]{3}@simulation\.local$' OR email NOT LIKE '%@simulation.local');
    END IF;
END $$;

-- Summary statistics
DO $$
DECLARE
    user_count INTEGER;
    total_users INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users WHERE username LIKE 'sim_user_%';
    SELECT COUNT(*) INTO total_users FROM users;
    
    RAISE NOTICE 'Simulation users migration completed:';
    RAISE NOTICE '  Simulation users: %', user_count;
    RAISE NOTICE '  Total users: %', total_users;
    RAISE NOTICE 'Migration is now idempotent and safe for pod restarts.';
END $$;
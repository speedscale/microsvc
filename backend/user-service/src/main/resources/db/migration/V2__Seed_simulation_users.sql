-- Migration to seed simulation users for the banking simulation client
-- This creates 1000 pre-existing users with realistic data for load testing
-- Note: Each service manages its own schema. This migration only creates users.
-- Accounts and transactions will be created by their respective services.

-- Insert simulation users
INSERT INTO users (username, email, password_hash, roles, created_at, updated_at)
SELECT 
    'sim_user_' || LPAD(generate_series::text, 3, '0') as username,
    'sim_user_' || LPAD(generate_series::text, 3, '0') || '@simulation.local' as email,
    -- BCrypt hash for 'NewUser123!' - matches what simulation client expects
    '$2a$10$7Gejer63hAKLgl/PEvESJ.CBuqHm5hvqFxU2Y4vmw1VJ6pdiEidmK' as password_hash,
    ARRAY['USER'] as roles,
    NOW() - (RANDOM() * INTERVAL '365 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '90 days') as updated_at
FROM generate_series(1, 1000);

-- Create index for better performance during simulation
CREATE INDEX IF NOT EXISTS idx_users_username_simulation ON users(username) WHERE username LIKE 'sim_user_%';

-- Add constraint to ensure data quality for simulation users
ALTER TABLE users ADD CONSTRAINT chk_simulation_user_email 
    CHECK (email ~ '^sim_user_[0-9]{3}@simulation\.local$' OR email NOT LIKE '%@simulation.local');

-- Summary statistics
DO $$
DECLARE
    user_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users WHERE username LIKE 'sim_user_%';
    
    RAISE NOTICE 'Simulation users seeded successfully:';
    RAISE NOTICE '  Users created: %', user_count;
    RAISE NOTICE 'Note: Accounts and transactions will be created by their respective services when users interact with the system.';
END $$;
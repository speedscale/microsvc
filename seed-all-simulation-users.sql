-- Seed all 1000 simulation users
INSERT INTO user_service.users (username, email, password_hash, roles, created_at, updated_at)
SELECT 
    'sim_user_' || LPAD(generate_series::text, 3, '0') as username,
    'sim_user_' || LPAD(generate_series::text, 3, '0') || '@simulation.local' as email,
    -- BCrypt hash for 'SimUser123!' (using cost factor 10)
    '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S' as password_hash,
    ARRAY['USER'] as roles,
    NOW() - (RANDOM() * INTERVAL '365 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '90 days') as updated_at
FROM generate_series(1, 1000)
ON CONFLICT (username) DO NOTHING;

-- Summary
DO $$
DECLARE
    user_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM user_service.users WHERE username LIKE 'sim_user_%';
    RAISE NOTICE 'Total simulation users: %', user_count;
END $$;
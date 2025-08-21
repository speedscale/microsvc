-- Seed a few test simulation users
INSERT INTO user_service.users (username, email, password_hash, roles, created_at, updated_at)
VALUES
    ('sim_user_001', 'sim_user_001@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_002', 'sim_user_002@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_003', 'sim_user_003@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_030', 'sim_user_030@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_136', 'sim_user_136@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_207', 'sim_user_207@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_277', 'sim_user_277@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_374', 'sim_user_374@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW()),
    ('sim_user_932', 'sim_user_932@simulation.local', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', ARRAY['USER'], NOW(), NOW());
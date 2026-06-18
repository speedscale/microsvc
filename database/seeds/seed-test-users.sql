-- Seed a few named test users.
INSERT INTO user_service.users (username, email, password_hash, roles, created_at, updated_at)
VALUES
    ('harper.clark.001', 'harper.clark.001@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('ava.thompson.002', 'ava.thompson.002@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('noah.martin.003', 'noah.martin.003@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('lucia.garcia.030', 'lucia.garcia.030@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('julia.lewandowski.136', 'julia.lewandowski.136@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('ava.campbell.207', 'ava.campbell.207@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('gabriel.pereira.277', 'gabriel.pereira.277@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('finn.smit.374', 'finn.smit.374@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW()),
    ('lina.schneider.932', 'lina.schneider.932@northbridge.example', '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S', 'USER', NOW(), NOW());

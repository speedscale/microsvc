-- Migration to seed named users for the banking traffic client.
-- This creates 1000 pre-existing users with realistic data.

CREATE OR REPLACE FUNCTION customer_seed_username(n INTEGER) RETURNS TEXT AS $$
DECLARE
    locale TEXT;
    first_name TEXT;
    last_name TEXT;
BEGIN
    locale := (ARRAY[
        'en-US', 'en-US', 'en-US', 'en-US', 'en-US',
        'en-GB', 'en-CA', 'en-AU',
        'es-MX', 'es-ES', 'fr-FR', 'de-DE', 'it-IT',
        'nl-NL', 'sv-SE', 'pl-PL', 'pt-BR',
        'ja-JP', 'ko-KR', 'zh-CN'
    ])[((n - 1) % 20) + 1];

    CASE locale
        WHEN 'en-US' THEN
            first_name := (ARRAY['Olivia','Emma','Ava','Sophia','Mia','Charlotte','Amelia','Harper','Liam','Noah','Ethan','Lucas'])[((n * 7) % 12) + 1];
            last_name := (ARRAY['Smith','Johnson','Williams','Brown','Miller','Davis','Wilson','Anderson','Taylor','Martin','Thompson','Clark'])[((n * 11) % 12) + 1];
        WHEN 'en-GB' THEN
            first_name := (ARRAY['Oliver','George','Harry','Jack','Arthur','Isla','Freya','Grace','Amelia','Florence'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Smith','Jones','Taylor','Brown','Williams','Wilson','Evans','Thomas','Roberts','Walker'])[((n * 11) % 10) + 1];
        WHEN 'en-CA' THEN
            first_name := (ARRAY['Liam','Noah','William','Lucas','Benjamin','Emma','Olivia','Charlotte','Sophia','Ava'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Smith','Brown','Tremblay','Martin','Roy','Wilson','Taylor','Campbell','Anderson','Lee'])[((n * 11) % 10) + 1];
        WHEN 'en-AU' THEN
            first_name := (ARRAY['Oliver','Noah','Jack','Henry','Leo','Charlotte','Olivia','Amelia','Isla','Mia'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Smith','Jones','Williams','Brown','Wilson','Taylor','Martin','Anderson','Thompson','White'])[((n * 11) % 10) + 1];
        WHEN 'es-MX' THEN
            first_name := (ARRAY['Sofia','Valentina','Camila','Regina','Mateo','Santiago','Diego','Emiliano','Lucia','Daniel'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Garcia','Hernandez','Lopez','Martinez','Gonzalez','Perez','Rodriguez','Sanchez','Ramirez','Torres'])[((n * 11) % 10) + 1];
        WHEN 'es-ES' THEN
            first_name := (ARRAY['Lucia','Sofia','Martina','Maria','Julia','Hugo','Martin','Lucas','Leo','Daniel'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Garcia','Rodriguez','Gonzalez','Fernandez','Lopez','Martinez','Sanchez','Perez','Gomez','Martin'])[((n * 11) % 10) + 1];
        WHEN 'fr-FR' THEN
            first_name := (ARRAY['Camille','Lea','Chloe','Manon','Emma','Hugo','Louis','Gabriel','Arthur','Jules'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Martin','Bernard','Dubois','Thomas','Robert','Richard','Petit','Durand','Leroy','Moreau'])[((n * 11) % 10) + 1];
        WHEN 'de-DE' THEN
            first_name := (ARRAY['Emma','Mia','Hannah','Sofia','Lina','Ben','Paul','Leon','Finn','Felix'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Muller','Schmidt','Schneider','Fischer','Weber','Meyer','Wagner','Becker','Hoffmann','Schulz'])[((n * 11) % 10) + 1];
        WHEN 'it-IT' THEN
            first_name := (ARRAY['Giulia','Sofia','Aurora','Alice','Ginevra','Leonardo','Francesco','Lorenzo','Alessandro','Mattia'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Rossi','Russo','Ferrari','Esposito','Bianchi','Romano','Colombo','Ricci','Marino','Greco'])[((n * 11) % 10) + 1];
        WHEN 'nl-NL' THEN
            first_name := (ARRAY['Emma','Tess','Sophie','Julia','Mila','Daan','Sem','Lucas','Finn','Levi'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['DeVries','Jansen','Bakker','Visser','Smit','Meijer','DeBoer','Mulder','Bos','Vos'])[((n * 11) % 10) + 1];
        WHEN 'sv-SE' THEN
            first_name := (ARRAY['Alice','Elsa','Maja','Lilly','Ella','Oscar','Lucas','William','Liam','Noah'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Andersson','Johansson','Karlsson','Nilsson','Eriksson','Larsson','Olsson','Persson','Svensson','Gustafsson'])[((n * 11) % 10) + 1];
        WHEN 'pl-PL' THEN
            first_name := (ARRAY['Zofia','Hanna','Julia','Maja','Laura','Jan','Antoni','Jakub','Aleksander','Szymon'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Nowak','Kowalski','Wisniewski','Wojcik','Kowalczyk','Kaminski','Lewandowski','Zielinski','Szymanski','Dabrowski'])[((n * 11) % 10) + 1];
        WHEN 'pt-BR' THEN
            first_name := (ARRAY['Ana','Beatriz','Mariana','Laura','Isabela','Joao','Pedro','Lucas','Miguel','Gabriel'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Silva','Santos','Oliveira','Souza','Rodrigues','Ferreira','Alves','Pereira','Lima','Gomes'])[((n * 11) % 10) + 1];
        WHEN 'ja-JP' THEN
            first_name := (ARRAY['Yuki','Haruto','Sota','Yuto','Ren','Hina','Sakura','Aoi','Mei','Rin'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Sato','Suzuki','Takahashi','Tanaka','Watanabe','Ito','Yamamoto','Nakamura','Kobayashi','Kato'])[((n * 11) % 10) + 1];
        WHEN 'ko-KR' THEN
            first_name := (ARRAY['SeoJun','DoYun','HaJun','JiHo','MinJun','SeoYeon','HaYoon','JiA','SeoAh','HaEun'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Kim','Lee','Park','Choi','Jung','Kang','Cho','Yoon','Jang','Lim'])[((n * 11) % 10) + 1];
        ELSE
            first_name := (ARRAY['Wei','Fang','Jing','Lei','Ming','Hao','Chen','Liang','Mei','Yan'])[((n * 7) % 10) + 1];
            last_name := (ARRAY['Wang','Li','Zhang','Liu','Chen','Yang','Huang','Zhao','Wu','Zhou'])[((n * 11) % 10) + 1];
    END CASE;

    RETURN LOWER(REGEXP_REPLACE(first_name, '[^A-Za-z0-9]+', '', 'g')) || '.' ||
           LOWER(REGEXP_REPLACE(last_name, '[^A-Za-z0-9]+', '', 'g')) || '.' ||
           LPAD(n::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

SELECT setseed(0.42);

-- Insert reusable customer users.
--
-- Pin the id to the seed number (1..1000) instead of letting BIGSERIAL assign it.
-- Why: recorded traffic carries JWTs whose `userId` claim is the seeded user's id,
-- and downstream account ownership is keyed on that id. With an unpinned BIGSERIAL,
-- every reseed hands a given seed user a different id, so previously-recorded JWTs
-- (and the accounts they own) go stale -- which makes traffic replay non-deterministic
-- (ownership checks return 404). Pinning id = generate_series keeps each seeded
-- identity stable across reseeds so e.g. `harry.evans.986` is always id 986.
INSERT INTO user_service.users (id, username, email, password_hash, roles, created_at, updated_at)
SELECT
    generate_series as id,
    customer_seed_username(generate_series) as username,
    customer_seed_username(generate_series) || '@northbridge.example' as email,
    -- BCrypt hash for 'SimUser123!'
    '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S' as password_hash,
    'USER' as roles,
    NOW() - (RANDOM() * INTERVAL '365 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '90 days') as updated_at
FROM generate_series(1, 1000);

-- Advance the identity sequence past the pinned seed block so users registered at
-- runtime never collide with (or get assigned into) a seeded id.
SELECT setval(pg_get_serial_sequence('user_service.users', 'id'), 1000, true);

-- Create accounts for simulation users with realistic balances
INSERT INTO accounts_service.accounts (user_id, account_number, account_type, balance, created_at, updated_at)
SELECT 
    u.id as user_id,
    'ACC' || LPAD((u.id * 1000 + 1)::text, 10, '0') as account_number,
    CASE 
        WHEN RANDOM() < 0.7 THEN 'CHECKING'
        WHEN RANDOM() < 0.9 THEN 'SAVINGS'  
        ELSE 'INVESTMENT'
    END as account_type,
    -- Generate realistic balance distribution
    CASE 
        WHEN RANDOM() < 0.3 THEN (RANDOM() * 990 + 10)::DECIMAL(15,2)      -- $10-$1,000 (30%)
        WHEN RANDOM() < 0.6 THEN (RANDOM() * 4900 + 100)::DECIMAL(15,2)    -- $100-$5,000 (30%)
        WHEN RANDOM() < 0.85 THEN (RANDOM() * 15000 + 5000)::DECIMAL(15,2) -- $5,000-$20,000 (25%)
        ELSE (RANDOM() * 30000 + 20000)::DECIMAL(15,2)                     -- $20,000-$50,000 (15%)
    END as balance,
    NOW() - (RANDOM() * INTERVAL '365 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '90 days') as updated_at
FROM user_service.users u 
WHERE u.email LIKE '%@northbridge.example';

-- Create some users with multiple accounts (20% of users)
INSERT INTO accounts_service.accounts (user_id, account_number, account_type, balance, created_at, updated_at)
SELECT 
    u.id as user_id,
    'ACC' || LPAD((u.id * 1000 + 2)::text, 10, '0') as account_number,
    CASE 
        WHEN RANDOM() < 0.5 THEN 'SAVINGS'
        ELSE 'INVESTMENT'
    END as account_type,
    (RANDOM() * 10000 + 500)::DECIMAL(15,2) as balance,
    NOW() - (RANDOM() * INTERVAL '300 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '60 days') as updated_at
FROM user_service.users u 
WHERE u.email LIKE '%@northbridge.example'
AND RANDOM() < 0.2; -- 20% of users get a second account

-- Create realistic transaction history for simulation users
INSERT INTO transactions_service.transactions (
    user_id, from_account_id, to_account_id, type, amount, description, 
    status, created_at
)
SELECT 
    a.user_id,
    CASE 
        WHEN t.transaction_type IN ('WITHDRAWAL', 'TRANSFER') THEN a.id
        ELSE NULL
    END as from_account_id,
    CASE 
        WHEN t.transaction_type = 'TRANSFER' THEN 
            (SELECT id FROM accounts_service.accounts 
             WHERE user_id != a.user_id 
             ORDER BY RANDOM() LIMIT 1)
        WHEN t.transaction_type = 'DEPOSIT' THEN a.id
        ELSE NULL
    END as to_account_id,
    t.transaction_type as type,
    t.amount,
    t.description,
    'COMPLETED' as status,
    t.created_at
FROM accounts_service.accounts a
CROSS JOIN LATERAL (
    SELECT 
        CASE 
            WHEN RANDOM() < 0.4 THEN 'DEPOSIT'
            WHEN RANDOM() < 0.7 THEN 'WITHDRAWAL'
            ELSE 'TRANSFER'
        END as transaction_type,
        CASE 
            WHEN RANDOM() < 0.4 THEN (RANDOM() * 500 + 10)::DECIMAL(15,2)   -- Small transactions
            WHEN RANDOM() < 0.8 THEN (RANDOM() * 2000 + 50)::DECIMAL(15,2)  -- Medium transactions  
            ELSE (RANDOM() * 5000 + 100)::DECIMAL(15,2)                     -- Large transactions
        END as amount,
        CASE 
            WHEN RANDOM() < 0.4 THEN 'Payroll deposit'
            WHEN RANDOM() < 0.6 THEN 'ATM withdrawal'
            WHEN RANDOM() < 0.8 THEN 'Online purchase'
            ELSE 'Transfer to friend'
        END as description,
        NOW() - (RANDOM() * INTERVAL '90 days') as created_at
    FROM generate_series(1, CASE WHEN RANDOM() < 0.3 THEN 1 WHEN RANDOM() < 0.7 THEN 2 ELSE 3 END)
) t
WHERE a.user_id IN (SELECT id FROM user_service.users WHERE email LIKE '%@northbridge.example')
AND RANDOM() < 0.8; -- 80% of accounts get transaction history

-- Update account balances to reflect transaction history
-- This is a simplified approach - in reality, balances would be calculated from transactions
UPDATE accounts_service.accounts 
SET balance = GREATEST(
    balance + 
    COALESCE((
        SELECT SUM(
            CASE 
                WHEN t.type = 'DEPOSIT' THEN t.amount
                WHEN t.type = 'WITHDRAWAL' THEN -t.amount
                WHEN t.type = 'TRANSFER' AND t.from_account_id = accounts_service.accounts.id THEN -t.amount
                WHEN t.type = 'TRANSFER' AND t.to_account_id = accounts_service.accounts.id THEN t.amount
                ELSE 0
            END
        )
        FROM transactions_service.transactions t
        WHERE t.from_account_id = accounts_service.accounts.id 
           OR t.to_account_id = accounts_service.accounts.id
    ), 0),
    10.00 -- Minimum balance of $10
)
WHERE user_id IN (SELECT id FROM user_service.users WHERE email LIKE '%@northbridge.example');

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email_seed_pool ON user_service.users(email) WHERE email LIKE '%@northbridge.example';
CREATE INDEX IF NOT EXISTS idx_accounts_user_id_simulation ON accounts_service.accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_simulation ON transactions_service.transactions(from_account_id, to_account_id);

-- Summary statistics
DO $$
DECLARE
    user_count INTEGER;
    account_count INTEGER;
    transaction_count INTEGER;
    total_balance DECIMAL(15,2);
BEGIN
    SELECT COUNT(*) INTO user_count FROM user_service.users WHERE email LIKE '%@northbridge.example';
    SELECT COUNT(*) INTO account_count FROM accounts_service.accounts a 
        JOIN user_service.users u ON a.user_id = u.id WHERE u.email LIKE '%@northbridge.example';
    SELECT COUNT(*) INTO transaction_count FROM transactions_service.transactions t
        JOIN accounts_service.accounts a ON t.from_account_id = a.id OR t.to_account_id = a.id
        JOIN user_service.users u ON a.user_id = u.id WHERE u.email LIKE '%@northbridge.example';
    SELECT SUM(balance) INTO total_balance FROM accounts_service.accounts a
        JOIN user_service.users u ON a.user_id = u.id WHERE u.email LIKE '%@northbridge.example';
    
    RAISE NOTICE 'Simulation data seeded successfully:';
    RAISE NOTICE '  Users created: %', user_count;
    RAISE NOTICE '  Accounts created: %', account_count;
    RAISE NOTICE '  Transactions created: %', transaction_count;
    RAISE NOTICE '  Total balance across all accounts: $%', total_balance;
END $$;

DROP FUNCTION customer_seed_username(INTEGER);

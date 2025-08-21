-- Migration to seed simulation users for the banking simulation client
-- This creates 1000 pre-existing users with realistic data for load testing

-- Create temporary function to generate random balance
CREATE OR REPLACE FUNCTION random_balance() RETURNS DECIMAL(15,2) AS $$
BEGIN
    -- Generate random balance between $100 and $50,000
    RETURN (RANDOM() * 49900 + 100)::DECIMAL(15,2);
END;
$$ LANGUAGE plpgsql;

-- Insert simulation users
INSERT INTO users (username, email, password_hash, roles, created_at, updated_at)
SELECT 
    'sim_user_' || LPAD(generate_series::text, 3, '0') as username,
    'sim_user_' || LPAD(generate_series::text, 3, '0') || '@simulation.local' as email,
    -- BCrypt hash for 'SimUser123!' (using cost factor 10)
    '$2a$10$8K1p/a0dqbCDEb1oK4dY4euWQeGpQm1l3F2N8H5Z6QvKbGcJeOw4S' as password_hash,
    ARRAY['USER'] as roles,
    NOW() - (RANDOM() * INTERVAL '365 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '90 days') as updated_at
FROM generate_series(1, 1000);

-- Drop the temporary function
DROP FUNCTION random_balance();

-- Create accounts for simulation users with realistic balances
INSERT INTO accounts_service.accounts (user_id, account_number, account_type, balance, status, created_at, updated_at)
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
    'ACTIVE' as status,
    NOW() - (RANDOM() * INTERVAL '365 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '90 days') as updated_at
FROM users u 
WHERE u.username LIKE 'sim_user_%';

-- Create some users with multiple accounts (20% of users)
INSERT INTO accounts_service.accounts (user_id, account_number, account_type, balance, status, created_at, updated_at)
SELECT 
    u.id as user_id,
    'ACC' || LPAD((u.id * 1000 + 2)::text, 10, '0') as account_number,
    CASE 
        WHEN RANDOM() < 0.5 THEN 'SAVINGS'
        ELSE 'INVESTMENT'
    END as account_type,
    (RANDOM() * 10000 + 500)::DECIMAL(15,2) as balance,
    'ACTIVE' as status,
    NOW() - (RANDOM() * INTERVAL '300 days') as created_at,
    NOW() - (RANDOM() * INTERVAL '60 days') as updated_at
FROM users u 
WHERE u.username LIKE 'sim_user_%' 
AND RANDOM() < 0.2; -- 20% of users get a second account

-- Create realistic transaction history for simulation users
INSERT INTO transactions_service.transactions (
    from_account_id, to_account_id, transaction_type, amount, description, 
    status, created_at, updated_at
)
SELECT 
    a.id as from_account_id,
    CASE 
        WHEN t.transaction_type = 'TRANSFER' THEN 
            (SELECT id FROM accounts_service.accounts 
             WHERE user_id != a.user_id 
             ORDER BY RANDOM() LIMIT 1)
        ELSE NULL
    END as to_account_id,
    t.transaction_type,
    t.amount,
    t.description,
    'COMPLETED' as status,
    t.created_at,
    t.created_at as updated_at
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
WHERE a.user_id IN (SELECT id FROM users WHERE username LIKE 'sim_user_%')
AND RANDOM() < 0.8; -- 80% of accounts get transaction history

-- Update account balances to reflect transaction history
-- This is a simplified approach - in reality, balances would be calculated from transactions
UPDATE accounts_service.accounts 
SET balance = GREATEST(
    balance + 
    COALESCE((
        SELECT SUM(
            CASE 
                WHEN t.transaction_type = 'DEPOSIT' THEN t.amount
                WHEN t.transaction_type = 'WITHDRAWAL' THEN -t.amount
                WHEN t.transaction_type = 'TRANSFER' AND t.from_account_id = accounts_service.accounts.id THEN -t.amount
                WHEN t.transaction_type = 'TRANSFER' AND t.to_account_id = accounts_service.accounts.id THEN t.amount
                ELSE 0
            END
        )
        FROM transactions_service.transactions t
        WHERE t.from_account_id = accounts_service.accounts.id 
           OR t.to_account_id = accounts_service.accounts.id
    ), 0),
    10.00 -- Minimum balance of $10
)
WHERE user_id IN (SELECT id FROM users WHERE username LIKE 'sim_user_%');

-- Create indexes for better performance during simulation
CREATE INDEX IF NOT EXISTS idx_users_username_simulation ON users(username) WHERE username LIKE 'sim_user_%';
CREATE INDEX IF NOT EXISTS idx_accounts_user_id_simulation ON accounts_service.accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_simulation ON transactions_service.transactions(from_account_id, to_account_id);

-- Add some constraints to ensure data quality
ALTER TABLE users ADD CONSTRAINT chk_simulation_user_email 
    CHECK (email ~ '^sim_user_[0-9]{3}@simulation\.local$' OR email NOT LIKE '%@simulation.local');

-- Summary statistics
DO $$
DECLARE
    user_count INTEGER;
    account_count INTEGER;
    transaction_count INTEGER;
    total_balance DECIMAL(15,2);
BEGIN
    SELECT COUNT(*) INTO user_count FROM users WHERE username LIKE 'sim_user_%';
    SELECT COUNT(*) INTO account_count FROM accounts_service.accounts a 
        JOIN users u ON a.user_id = u.id WHERE u.username LIKE 'sim_user_%';
    SELECT COUNT(*) INTO transaction_count FROM transactions_service.transactions t
        JOIN accounts_service.accounts a ON t.from_account_id = a.id OR t.to_account_id = a.id
        JOIN users u ON a.user_id = u.id WHERE u.username LIKE 'sim_user_%';
    SELECT SUM(balance) INTO total_balance FROM accounts_service.accounts a
        JOIN users u ON a.user_id = u.id WHERE u.username LIKE 'sim_user_%';
    
    RAISE NOTICE 'Simulation data seeded successfully:';
    RAISE NOTICE '  Users created: %', user_count;
    RAISE NOTICE '  Accounts created: %', account_count;
    RAISE NOTICE '  Transactions created: %', transaction_count;
    RAISE NOTICE '  Total balance across all accounts: $%', total_balance;
END $$;
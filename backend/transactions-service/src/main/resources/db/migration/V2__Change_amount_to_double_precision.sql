-- Change amount column from DECIMAL to DOUBLE PRECISION for Java Double compatibility
ALTER TABLE transactions_service.transactions 
ALTER COLUMN amount TYPE DOUBLE PRECISION USING amount::DOUBLE PRECISION;

-- Update the positive amount constraint since DOUBLE PRECISION handles precision differently
ALTER TABLE transactions_service.transactions 
DROP CONSTRAINT IF EXISTS chk_amount_positive;

ALTER TABLE transactions_service.transactions 
ADD CONSTRAINT chk_amount_positive 
CHECK (amount > 0.0);
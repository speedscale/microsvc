-- Script to fix Flyway migration issues
-- Run this if V2 migration failed and left the schema_version table in an inconsistent state

-- Check current Flyway migration status
SELECT version, description, type, script, checksum, installed_by, installed_on, execution_time, success 
FROM user_service.flyway_schema_history 
ORDER BY installed_rank;

-- If V2 migration shows success = false, we need to delete it so it can retry
-- ONLY run this if V2 migration failed:
-- DELETE FROM user_service.flyway_schema_history WHERE version = '2' AND success = false;

-- After fixing, the service should be able to run V3 migration successfully
# Demo Data Generation Test Plan

## Issue
User registered with demo data checkbox checked, but no accounts appeared after login.

## Debugging Steps

### 1. Verify Frontend is Sending Correct Data
- Check browser network tab during registration
- Verify `generateDemoData: true` is being sent in the request body
- Check if the request reaches the backend

### 2. Verify Backend Processing
- Check user service logs for:
  - "Registering new user: {username} with demo data: true"
  - "Demo data generation requested for user: {username}"
  - "Generated JWT token for demo data creation, user ID: {id}"
  - "Demo data generated successfully for user: {username}"

### 3. Verify Service Communication
- Check if accounts service is running on port 8081
- Check if transactions service is running on port 8082
- Verify JWT token is valid for service-to-service calls
- Check if X-User-Id header is being set correctly

### 4. Test Direct API Calls
Test the registration endpoint directly:

```bash
curl -X POST http://localhost:8080/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser123",
    "email": "test123@example.com",
    "password": "password123",
    "generateDemoData": true
  }'
```

### 5. Check Database
After registration, verify:
- User exists in user_service.users table
- Accounts exist in accounts_service.accounts table
- Transactions exist in transactions_service.transactions table

### 6. Common Issues to Check
1. **Service URLs**: Verify accounts and transactions services are accessible
2. **JWT Token**: Ensure the generated token is valid and has correct permissions
3. **Database Connections**: Verify all services can connect to their respective database schemas
4. **CORS/Headers**: Check if X-User-Id header is being processed correctly
5. **Error Handling**: Demo data generation failures might be silently ignored

## Expected Behavior
1. User registers with demo data checkbox checked
2. User service creates user account
3. User service generates JWT token
4. User service calls accounts service to create 2 accounts
5. User service calls transactions service to create 10 transactions
6. User logs in and sees 2 accounts with transactions

## Next Steps
1. Start all services (user, accounts, transactions, API gateway)
2. Monitor logs during registration
3. Check database state after registration
4. Verify accounts appear in frontend after login 
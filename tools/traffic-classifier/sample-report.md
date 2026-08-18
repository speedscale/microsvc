# Traffic classifier run

Source: `sample`  
Window: 2026-08-06T20:00:12.438851+00:00 to 2026-08-06T20:04:59.929276+00:00  
Calls: 594 across 14 endpoints, 53 identities, 53 sessions  
Identity from: session 501, payload 93

## Workflows

| # | Workflow | Kind | Sessions | Calls | Steps | Errors | Data tier | Priority |
| - | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Login & Dashboard Overview | action | 34 | 225 | 5 | 1.3% | restricted | high |
| 2 | Fund Account Deposit | action | 23 | 43 | 1 | 27.9% | restricted | high |
| 3 | Transfer Funds & Verify Balance | action | 20 | 104 | 5 | 7.7% | restricted | high |
| 4 | Login & Account Overview | action | 12 | 36 | 3 | 0.0% | restricted | medium |
| 5 | Registration Availability Check | journey | 12 | 24 | 2 | 0.0% | restricted | medium |
| 6 | User Registration | action | 12 | 12 | 1 | 0.0% | restricted | high |
| 7 | Transfer Funds & Check Balance | action | 11 | 37 | 3 | 10.8% | restricted | high |
| 8 | Transfer Funds & View History | action | 11 | 22 | 2 | 0.0% | restricted | high |
| 9 | User Authentication | action | 9 | 9 | 1 | 88.9% | restricted | high |
| 10 | Initiate Fund Transfer | action | 8 | 8 | 1 | 12.5% | restricted | high |
| 11 | Create Account & Full Review | action | 7 | 35 | 5 | 0.0% | restricted | high |
| 12 | Create Account & Verify Balance | action | 6 | 18 | 3 | 0.0% | restricted | high |
| 13 | Account List Polling | polling | 2 | 8 | 1 | 100.0% | restricted | low |
| 14 | Login & Profile Retrieval | action | 2 | 4 | 2 | 0.0% | restricted | medium |
| 15 | Export Account Statement | action | 2 | 2 | 1 | 0.0% | restricted | medium |

## Workflow detail

### 1. Login & Dashboard Overview

The user authenticates, retrieves their profile, views their account list and balances, and checks recent transaction history.

1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`
4. `GET /api/accounts/{id}/balance`
5. `GET /api/transactions`

Data classes: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 2. Fund Account Deposit

The user initiates a direct deposit or funding transaction into a specific account.

1. `POST /api/transactions/deposit`

Data classes: `bank_account` (restricted), `credential` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 3. Transfer Funds & Verify Balance

The user creates a fund transfer, then verifies the updated account balances and transaction history.

1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`
4. `GET /api/accounts/{id}`
5. `GET /api/transactions`

Data classes: `bank_account` (restricted), `credential` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 4. Login & Account Overview

The user authenticates and immediately views their profile and list of associated accounts.

1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`

Data classes: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 5. Registration Availability Check

The system validates the availability of a chosen username and email address before registration.

1. `GET /api/users/check-username`
2. `GET /api/users/check-email`

Data classes: `credential` (restricted), `free_text` (confidential)

### 6. User Registration

A new user creates an account by submitting registration details.

1. `POST /api/users/register`

Data classes: `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `identifier` (internal), `timestamp` (internal)

### 7. Transfer Funds & Check Balance

The user initiates a fund transfer and immediately checks the updated account list and balance.

1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes: `bank_account` (restricted), `credential` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 8. Transfer Funds & View History

The user creates a fund transfer and then retrieves the updated transaction history.

1. `POST /api/transactions/create`
2. `GET /api/transactions`

Data classes: `credential` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 9. User Authentication

The user submits credentials to authenticate and receive an access token.

1. `POST /api/users/login`

Data classes: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal)

### 10. Initiate Fund Transfer

The user submits a request to transfer funds between accounts.

1. `POST /api/transactions/create`

Data classes: `credential` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 11. Create Account & Full Review

The user opens a new account and then reviews the account list, balance, details, and transaction history.

1. `POST /api/accounts`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`
4. `GET /api/accounts/{id}`
5. `GET /api/transactions`

Data classes: `bank_account` (restricted), `credential` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 12. Create Account & Verify Balance

The user opens a new account and immediately checks the updated account list and initial balance.

1. `POST /api/accounts`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes: `bank_account` (restricted), `credential` (restricted), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 13. Account List Polling

The client repeatedly fetches the account list to monitor for updates or synchronization.

1. `GET /api/accounts`

Data classes: `bank_account` (restricted), `credential` (restricted), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 14. Login & Profile Retrieval

The user authenticates and fetches their personal profile information.

1. `POST /api/users/login`
2. `GET /api/users/profile`

Data classes: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `timestamp` (internal)

### 15. Export Account Statement

The user requests a formal statement export for a specific account.

1. `POST /api/accounts/{id}/export-statement`

Data classes: `bank_account` (restricted), `credential` (restricted), `identifier` (internal), `money` (confidential), `timestamp` (internal)

## Endpoint health

| Endpoint | Calls | Errors | Status codes | Tier |
| --- | ---: | ---: | --- | --- |
| `POST /api/transactions/deposit` | 23 | 52.2% | 400 x12, 201 x11 | restricted |
| `POST /api/users/login` | 57 | 14.0% | 200 x49, 401 x7, 503 x1 | restricted |
| `GET /api/accounts/{id}/balance` | 107 | 12.2% | 200 x94, 404 x12, 503 x1 | restricted |
| `GET /api/accounts` | 114 | 7.0% | 200 x106, 401 x8 | restricted |
| `GET /api/users/profile` | 49 | 2.0% | 200 x48, 503 x1 | restricted |
| `POST /api/transactions/create` | 50 | 2.0% | 201 x49, 503 x1 | restricted |
| `GET /api/transactions` | 100 | 1.0% | 200 x99, 503 x1 | restricted |
| `GET /api/accounts/{id}` | 42 | 0.0% | 200 x42 | restricted |
| `POST /api/accounts` | 13 | 0.0% | 201 x13 | restricted |
| `GET /api/users/check-username` | 12 | 0.0% | 200 x12 | restricted |
| `GET /api/users/check-email` | 12 | 0.0% | 200 x12 | restricted |
| `POST /api/users/register` | 12 | 0.0% | 201 x12 | restricted |
| `POST /api/accounts/{id}/export-statement` | 2 | 0.0% | 200 x2 | restricted |
| `POST /api/transactions/withdraw` | 1 | 0.0% | 201 x1 | restricted |

## Data classes by field

| Endpoint | Side | Field | Class | Tier | Free text hits |
| --- | --- | --- | --- | --- | ---: |
| `GET /api/accounts` | request | `$api_key` | credential | restricted |  |
| `GET /api/accounts` | response | `[].accountNumber` | bank_account | restricted |  |
| `GET /api/accounts` | response | `[].balance` | money | confidential |  |
| `GET /api/accounts` | response | `[].createdAt` | timestamp | internal |  |
| `GET /api/accounts` | response | `[].id` | identifier | internal |  |
| `GET /api/accounts` | response | `[].updatedAt` | timestamp | internal |  |
| `GET /api/accounts` | response | `[].userId` | identifier | internal |  |
| `GET /api/accounts/{id}` | request | `$api_key` | credential | restricted |  |
| `GET /api/accounts/{id}` | response | `accountNumber` | bank_account | restricted |  |
| `GET /api/accounts/{id}` | response | `balance` | money | confidential |  |
| `GET /api/accounts/{id}` | response | `createdAt` | timestamp | internal |  |
| `GET /api/accounts/{id}` | response | `id` | identifier | internal |  |
| `GET /api/accounts/{id}` | response | `updatedAt` | timestamp | internal |  |
| `GET /api/accounts/{id}` | response | `userId` | identifier | internal |  |
| `GET /api/accounts/{id}/balance` | request | `$api_key` | credential | restricted |  |
| `GET /api/accounts/{id}/balance` | response | `accountId` | identifier | internal |  |
| `GET /api/accounts/{id}/balance` | response | `accountNumber` | bank_account | restricted |  |
| `GET /api/accounts/{id}/balance` | response | `balance` | money | confidential |  |
| `GET /api/transactions` | request | `$api_key` | credential | restricted |  |
| `GET /api/transactions` | response | `[].amount` | money | confidential |  |
| `GET /api/transactions` | response | `[].createdAt` | timestamp | internal |  |
| `GET /api/transactions` | response | `[].description` | free_text | confidential |  |
| `GET /api/transactions` | response | `[].fromAccountId` | identifier | internal |  |
| `GET /api/transactions` | response | `[].id` | identifier | internal |  |
| `GET /api/transactions` | response | `[].processedAt` | timestamp | internal |  |
| `GET /api/transactions` | response | `[].toAccountId` | identifier | internal |  |
| `GET /api/transactions` | response | `[].userId` | identifier | internal |  |
| `GET /api/users/check-email` | request | `$api_key` | credential | restricted |  |
| `GET /api/users/check-email` | response | `message` | free_text | confidential |  |
| `GET /api/users/check-username` | request | `$api_key` | credential | restricted |  |
| `GET /api/users/check-username` | response | `message` | free_text | confidential |  |
| `GET /api/users/profile` | request | `$api_key` | credential | restricted |  |
| `GET /api/users/profile` | response | `data.createdAt` | timestamp | internal |  |
| `GET /api/users/profile` | response | `data.email` | email | confidential |  |
| `GET /api/users/profile` | response | `data.id` | identifier | internal |  |
| `GET /api/users/profile` | response | `data.updatedAt` | timestamp | internal |  |
| `GET /api/users/profile` | response | `data.username` | credentials_hint | internal |  |
| `GET /api/users/profile` | response | `message` | free_text | confidential |  |
| `POST /api/accounts` | request | `$api_key` | credential | restricted |  |
| `POST /api/accounts` | request | `initialBalance` | money | confidential |  |
| `POST /api/accounts` | response | `accountNumber` | bank_account | restricted |  |
| `POST /api/accounts` | response | `balance` | money | confidential |  |
| `POST /api/accounts` | response | `createdAt` | timestamp | internal |  |
| `POST /api/accounts` | response | `id` | identifier | internal |  |
| `POST /api/accounts` | response | `updatedAt` | timestamp | internal |  |
| `POST /api/accounts` | response | `userId` | identifier | internal |  |
| `POST /api/accounts/{id}/export-statement` | request | `$api_key` | credential | restricted |  |
| `POST /api/accounts/{id}/export-statement` | response | `statement.accountId` | identifier | internal |  |
| `POST /api/accounts/{id}/export-statement` | response | `statement.accountNumber` | bank_account | restricted |  |
| `POST /api/accounts/{id}/export-statement` | response | `statement.balance` | money | confidential |  |
| `POST /api/accounts/{id}/export-statement` | response | `statement.exportedAt` | timestamp | internal |  |
| `POST /api/accounts/{id}/export-statement` | response | `statement.userId` | identifier | internal |  |
| `POST /api/transactions/create` | request | `$api_key` | credential | restricted |  |
| `POST /api/transactions/create` | request | `accountId` | identifier | internal |  |
| `POST /api/transactions/create` | request | `amount` | money | confidential |  |
| `POST /api/transactions/create` | request | `currency` | money | confidential |  |
| `POST /api/transactions/create` | request | `description` | free_text | confidential |  |
| `POST /api/transactions/create` | response | `amount` | money | confidential |  |
| `POST /api/transactions/create` | response | `createdAt` | timestamp | internal |  |
| `POST /api/transactions/create` | response | `description` | free_text | confidential |  |
| `POST /api/transactions/create` | response | `fromAccountId` | identifier | internal |  |
| `POST /api/transactions/create` | response | `id` | identifier | internal |  |
| `POST /api/transactions/create` | response | `processedAt` | timestamp | internal |  |
| `POST /api/transactions/create` | response | `toAccountId` | identifier | internal |  |
| `POST /api/transactions/create` | response | `userId` | identifier | internal |  |
| `POST /api/transactions/deposit` | request | `$api_key` | credential | restricted |  |
| `POST /api/transactions/deposit` | request | `accountId` | identifier | internal |  |
| `POST /api/transactions/deposit` | request | `amount` | money | confidential |  |
| `POST /api/transactions/deposit` | request | `currency` | money | confidential |  |
| `POST /api/transactions/deposit` | request | `description` | free_text | confidential |  |
| `POST /api/transactions/deposit` | response | `amount` | money | confidential |  |
| `POST /api/transactions/deposit` | response | `createdAt` | timestamp | internal |  |
| `POST /api/transactions/deposit` | response | `description` | free_text | confidential |  |
| `POST /api/transactions/deposit` | response | `id` | identifier | internal |  |
| `POST /api/transactions/deposit` | response | `processedAt` | timestamp | internal |  |
| `POST /api/transactions/deposit` | response | `toAccountId` | identifier | internal |  |
| `POST /api/transactions/deposit` | response | `userId` | identifier | internal |  |
| `POST /api/transactions/withdraw` | request | `$api_key` | credential | restricted |  |
| `POST /api/transactions/withdraw` | request | `accountId` | identifier | internal |  |
| `POST /api/transactions/withdraw` | request | `amount` | money | confidential |  |
| `POST /api/transactions/withdraw` | request | `currency` | money | confidential |  |
| `POST /api/transactions/withdraw` | request | `description` | free_text | confidential |  |
| `POST /api/transactions/withdraw` | response | `amount` | money | confidential |  |
| `POST /api/transactions/withdraw` | response | `createdAt` | timestamp | internal |  |
| `POST /api/transactions/withdraw` | response | `description` | free_text | confidential |  |
| `POST /api/transactions/withdraw` | response | `fromAccountId` | identifier | internal |  |
| `POST /api/transactions/withdraw` | response | `id` | identifier | internal |  |
| `POST /api/transactions/withdraw` | response | `processedAt` | timestamp | internal |  |
| `POST /api/transactions/withdraw` | response | `userId` | identifier | internal |  |
| `POST /api/users/login` | request | `$api_key` | credential | restricted |  |
| `POST /api/users/login` | request | `password` | credential | restricted |  |
| `POST /api/users/login` | request | `usernameOrEmail` | email | confidential |  |
| `POST /api/users/login` | response | `email` | email | confidential |  |
| `POST /api/users/login` | response | `id` | identifier | internal |  |
| `POST /api/users/login` | response | `message` | free_text | confidential |  |
| `POST /api/users/login` | response | `token` | auth_token | confidential |  |
| `POST /api/users/login` | response | `username` | credentials_hint | internal |  |
| `POST /api/users/register` | request | `$api_key` | credential | restricted |  |
| `POST /api/users/register` | request | `email` | email | confidential |  |
| `POST /api/users/register` | request | `password` | credential | restricted |  |
| `POST /api/users/register` | request | `username` | credentials_hint | internal |  |
| `POST /api/users/register` | response | `createdAt` | timestamp | internal |  |
| `POST /api/users/register` | response | `email` | email | confidential |  |
| `POST /api/users/register` | response | `id` | identifier | internal |  |
| `POST /api/users/register` | response | `username` | credentials_hint | internal |  |

## Coverage

- `POST /api/transactions/withdraw` seen in traffic but in no workflow

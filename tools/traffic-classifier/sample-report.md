# Traffic classifier run

Source: `sample`  
Window: 2026-08-06T20:00:12.438851+00:00 to 2026-08-06T20:09:59.633782+00:00  
Calls: 1158 across 14 endpoints, 95 distinct identities, 97 sessions  

Identity resolved from: token 984, payload 162, none 12 (12 uncorrelated calls excluded from sessions)

## Workflows

| # | Workflow | Kind | Sessions | Calls | Steps | Errors | Data tier | Test priority |
| - | -------- | ---- | -------: | ----: | ----: | -----: | --------- | ------------- |
| 1 | Account Overview & Transaction History | action | 73 | 492 | 5 | 0.6% | restricted | high |
| 2 | Fund Deposit | action | 58 | 118 | 1 | 28.0% | restricted | high |
| 3 | Fund Transfer & Verification | action | 33 | 173 | 5 | 4.6% | restricted | high |
| 4 | Quick Transfer & History Check | action | 24 | 48 | 2 | 0.0% | confidential | medium |
| 5 | Transfer & Balance Verification | action | 22 | 79 | 3 | 16.5% | restricted | high |
| 6 | New Account Creation | action | 19 | 73 | 3 | 0.0% | restricted | high |
| 7 | User Registration | action | 19 | 19 | 1 | 5.3% | restricted | high |
| 8 | Login & Account Dashboard | action | 18 | 54 | 3 | 0.0% | restricted | high |
| 9 | Registration Availability Check | journey | 18 | 36 | 2 | 0.0% | confidential | medium |
| 10 | Initiate Transfer | action | 14 | 14 | 1 | 7.1% | confidential | high |
| 11 | User Authentication | action | 13 | 13 | 1 | 92.3% | restricted | high |
| 12 | Statement Export | action | 6 | 6 | 1 | 16.7% | restricted | medium |
| 13 | Fund Withdrawal & History | action | 3 | 9 | 2 | 0.0% | restricted | high |
| 14 | Login & Profile View | action | 2 | 4 | 2 | 0.0% | restricted | medium |

## Workflow detail

### 1. Account Overview & Transaction History

User logs in and reviews their profile, account balances, and recent transaction history.

Test priority **high** — Covers core authentication, account viewing, and transaction listing which are daily banking activities.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`
4. `GET /api/accounts/{id}/balance`
5. `GET /api/transactions`

Data classes touched: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 2. Fund Deposit

User initiates a direct deposit into a specific account.

Test priority **high** — Critical financial transaction that directly impacts account balance and requires strict validation.

Steps:
1. `POST /api/transactions/deposit`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 3. Fund Transfer & Verification

User creates a payment or transfer between accounts and immediately verifies the updated account details and transaction log.

Test priority **high** — Covers the complete transfer lifecycle including creation and post-action verification, central to banking operations.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`
4. `GET /api/accounts/{id}`
5. `GET /api/transactions`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 4. Quick Transfer & History Check

User initiates a transaction and immediately views the updated transaction history.

Test priority **medium** — Common user flow but lacks account balance verification, making it slightly less critical than full verification flows.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/transactions`

Data classes touched: `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 5. Transfer & Balance Verification

User executes a transaction and confirms the resulting account balances.

Test priority **high** — Directly tests the core financial operation of moving funds and verifying balance updates.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 6. New Account Creation

User opens a new account and verifies its creation and initial balance.

Test priority **high** — Account provisioning is a foundational banking operation with significant compliance and data integrity implications.

Steps:
1. `POST /api/accounts`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 7. User Registration

User creates a new account by providing email, password, and username.

Test priority **high** — Entry point for all new users; failures here block all downstream banking activities.

Steps:
1. `POST /api/users/register`

Data classes touched: `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `identifier` (internal), `timestamp` (internal)

### 8. Login & Account Dashboard

User authenticates and navigates to their profile and account summary dashboard.

Test priority **high** — Standard post-login navigation flow that users perform frequently; critical for session management and data access.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`

Data classes touched: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 9. Registration Availability Check

User verifies the availability of a desired username and email address before registering.

Test priority **medium** — Important for registration UX but does not complete a transaction or create persistent state on its own.

Steps:
1. `GET /api/users/check-username`
2. `GET /api/users/check-email`

Data classes touched: `free_text` (confidential)

### 10. Initiate Transfer

User submits a request to create a new financial transaction.

Test priority **high** — Core banking action that directly modifies financial records and requires robust error handling and validation.

Steps:
1. `POST /api/transactions/create`

Data classes touched: `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 11. User Authentication

User authenticates their credentials to access the banking platform.

Test priority **high** — Fundamental security and access control mechanism; any failure completely blocks user access.

Steps:
1. `POST /api/users/login`

Data classes touched: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal)

### 12. Statement Export

User requests and downloads a financial statement for a specific account.

Test priority **medium** — Important compliance and record-keeping feature, but less frequently used than core transactional flows.

Steps:
1. `POST /api/accounts/{id}/export-statement`

Data classes touched: `bank_account` (restricted), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 13. Fund Withdrawal & History

User initiates a withdrawal and reviews the transaction log to confirm the action.

Test priority **high** — Directly impacts account balance and involves critical financial outflow validation.

Steps:
1. `POST /api/transactions/withdraw`
2. `GET /api/transactions`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 14. Login & Profile View

User authenticates and immediately views their personal profile information.

Test priority **medium** — Common navigation pattern but focuses only on read-only profile data without account or transaction interactions.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`

Data classes touched: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `timestamp` (internal)

## Endpoint health

| Endpoint | Calls | Errors | Status codes | Data tier |
| -------- | ----: | -----: | ------------ | --------- |
| `POST /api/transactions/deposit` | 58 | 48.3% | 201 x30, 400 x27, 500 x1 | confidential |
| `POST /api/accounts/{id}/export-statement` | 6 | 16.7% | 200 x5, 503 x1 | restricted |
| `GET /api/accounts/{id}/balance` | 211 | 12.3% | 200 x185, 404 x24, 503 x1, 500 x1 | restricted |
| `POST /api/users/login` | 107 | 11.2% | 200 x95, 401 x11, 503 x1 | restricted |
| `GET /api/accounts` | 216 | 6.0% | 200 x203, 401 x12, 500 x1 | restricted |
| `POST /api/users/register` | 19 | 5.3% | 201 x18, 503 x1 | restricted |
| `POST /api/transactions/create` | 93 | 1.1% | 201 x92, 503 x1 | confidential |
| `GET /api/users/profile` | 95 | 1.1% | 200 x94, 503 x1 | confidential |
| `GET /api/transactions` | 214 | 0.5% | 200 x213, 503 x1 | confidential |
| `GET /api/accounts/{id}` | 81 | 0.0% | 200 x81 | restricted |
| `POST /api/accounts` | 19 | 0.0% | 201 x19 | restricted |
| `GET /api/users/check-username` | 18 | 0.0% | 200 x18 | confidential |
| `GET /api/users/check-email` | 18 | 0.0% | 200 x18 | confidential |
| `POST /api/transactions/withdraw` | 3 | 0.0% | 201 x3 | confidential |

## Data classification by endpoint

| Endpoint | Side | Field | Class | Tier |
| -------- | ---- | ----- | ----- | ---- |
| `GET /api/accounts` | response | `[].accountNumber` | bank_account | restricted |
| `GET /api/accounts` | response | `[].balance` | money | confidential |
| `GET /api/accounts` | response | `[].createdAt` | timestamp | internal |
| `GET /api/accounts` | response | `[].id` | identifier | internal |
| `GET /api/accounts` | response | `[].updatedAt` | timestamp | internal |
| `GET /api/accounts` | response | `[].userId` | identifier | internal |
| `GET /api/accounts/{id}` | response | `accountNumber` | bank_account | restricted |
| `GET /api/accounts/{id}` | response | `balance` | money | confidential |
| `GET /api/accounts/{id}` | response | `createdAt` | timestamp | internal |
| `GET /api/accounts/{id}` | response | `id` | identifier | internal |
| `GET /api/accounts/{id}` | response | `updatedAt` | timestamp | internal |
| `GET /api/accounts/{id}` | response | `userId` | identifier | internal |
| `GET /api/accounts/{id}/balance` | response | `accountId` | identifier | internal |
| `GET /api/accounts/{id}/balance` | response | `accountNumber` | bank_account | restricted |
| `GET /api/accounts/{id}/balance` | response | `balance` | money | confidential |
| `GET /api/transactions` | response | `[].amount` | money | confidential |
| `GET /api/transactions` | response | `[].createdAt` | timestamp | internal |
| `GET /api/transactions` | response | `[].description` | free_text | confidential |
| `GET /api/transactions` | response | `[].fromAccountId` | identifier | internal |
| `GET /api/transactions` | response | `[].id` | identifier | internal |
| `GET /api/transactions` | response | `[].processedAt` | timestamp | internal |
| `GET /api/transactions` | response | `[].toAccountId` | identifier | internal |
| `GET /api/transactions` | response | `[].userId` | identifier | internal |
| `GET /api/users/check-email` | response | `message` | free_text | confidential |
| `GET /api/users/check-username` | response | `message` | free_text | confidential |
| `GET /api/users/profile` | response | `data.createdAt` | timestamp | internal |
| `GET /api/users/profile` | response | `data.email` | email | confidential |
| `GET /api/users/profile` | response | `data.id` | identifier | internal |
| `GET /api/users/profile` | response | `data.updatedAt` | timestamp | internal |
| `GET /api/users/profile` | response | `data.username` | credentials_hint | internal |
| `GET /api/users/profile` | response | `message` | free_text | confidential |
| `POST /api/accounts` | request | `initialBalance` | money | confidential |
| `POST /api/accounts` | response | `accountNumber` | bank_account | restricted |
| `POST /api/accounts` | response | `balance` | money | confidential |
| `POST /api/accounts` | response | `createdAt` | timestamp | internal |
| `POST /api/accounts` | response | `id` | identifier | internal |
| `POST /api/accounts` | response | `updatedAt` | timestamp | internal |
| `POST /api/accounts` | response | `userId` | identifier | internal |
| `POST /api/accounts/{id}/export-statement` | response | `statement.accountId` | identifier | internal |
| `POST /api/accounts/{id}/export-statement` | response | `statement.accountNumber` | bank_account | restricted |
| `POST /api/accounts/{id}/export-statement` | response | `statement.balance` | money | confidential |
| `POST /api/accounts/{id}/export-statement` | response | `statement.exportedAt` | timestamp | internal |
| `POST /api/accounts/{id}/export-statement` | response | `statement.userId` | identifier | internal |
| `POST /api/transactions/create` | request | `accountId` | identifier | internal |
| `POST /api/transactions/create` | request | `amount` | money | confidential |
| `POST /api/transactions/create` | request | `currency` | money | confidential |
| `POST /api/transactions/create` | request | `description` | free_text | confidential |
| `POST /api/transactions/create` | response | `amount` | money | confidential |
| `POST /api/transactions/create` | response | `createdAt` | timestamp | internal |
| `POST /api/transactions/create` | response | `description` | free_text | confidential |
| `POST /api/transactions/create` | response | `fromAccountId` | identifier | internal |
| `POST /api/transactions/create` | response | `id` | identifier | internal |
| `POST /api/transactions/create` | response | `processedAt` | timestamp | internal |
| `POST /api/transactions/create` | response | `toAccountId` | identifier | internal |
| `POST /api/transactions/create` | response | `userId` | identifier | internal |
| `POST /api/transactions/deposit` | request | `accountId` | identifier | internal |
| `POST /api/transactions/deposit` | request | `amount` | money | confidential |
| `POST /api/transactions/deposit` | request | `currency` | money | confidential |
| `POST /api/transactions/deposit` | request | `description` | free_text | confidential |
| `POST /api/transactions/deposit` | response | `amount` | money | confidential |
| `POST /api/transactions/deposit` | response | `createdAt` | timestamp | internal |
| `POST /api/transactions/deposit` | response | `description` | free_text | confidential |
| `POST /api/transactions/deposit` | response | `id` | identifier | internal |
| `POST /api/transactions/deposit` | response | `processedAt` | timestamp | internal |
| `POST /api/transactions/deposit` | response | `toAccountId` | identifier | internal |
| `POST /api/transactions/deposit` | response | `userId` | identifier | internal |
| `POST /api/transactions/withdraw` | request | `accountId` | identifier | internal |
| `POST /api/transactions/withdraw` | request | `amount` | money | confidential |
| `POST /api/transactions/withdraw` | request | `currency` | money | confidential |
| `POST /api/transactions/withdraw` | request | `description` | free_text | confidential |
| `POST /api/transactions/withdraw` | response | `amount` | money | confidential |
| `POST /api/transactions/withdraw` | response | `createdAt` | timestamp | internal |
| `POST /api/transactions/withdraw` | response | `description` | free_text | confidential |
| `POST /api/transactions/withdraw` | response | `fromAccountId` | identifier | internal |
| `POST /api/transactions/withdraw` | response | `id` | identifier | internal |
| `POST /api/transactions/withdraw` | response | `processedAt` | timestamp | internal |
| `POST /api/transactions/withdraw` | response | `userId` | identifier | internal |
| `POST /api/users/login` | request | `password` | credential | restricted |
| `POST /api/users/login` | request | `usernameOrEmail` | email | confidential |
| `POST /api/users/login` | response | `email` | email | confidential |
| `POST /api/users/login` | response | `id` | identifier | internal |
| `POST /api/users/login` | response | `message` | free_text | confidential |
| `POST /api/users/login` | response | `token` | auth_token | confidential |
| `POST /api/users/login` | response | `username` | credentials_hint | internal |
| `POST /api/users/register` | request | `email` | email | confidential |
| `POST /api/users/register` | request | `password` | credential | restricted |
| `POST /api/users/register` | request | `username` | credentials_hint | internal |
| `POST /api/users/register` | response | `createdAt` | timestamp | internal |
| `POST /api/users/register` | response | `email` | email | confidential |
| `POST /api/users/register` | response | `id` | identifier | internal |
| `POST /api/users/register` | response | `username` | credentials_hint | internal |

## Unstructured fields (free text that may carry PII)

None found in this capture.

## Coverage gaps

Every observed endpoint appears in at least one workflow.

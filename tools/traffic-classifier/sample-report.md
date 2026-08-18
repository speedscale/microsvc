# Traffic classifier run

Source: `sample`  
Window: 2026-08-06T20:00:12.438851+00:00 to 2026-08-06T20:04:59.929276+00:00  
Calls: 594 across 14 endpoints, 52 distinct identities, 52 sessions  

Identity resolved from: token 493, payload 93, none 8 (8 uncorrelated calls excluded from sessions)

## Workflows

| # | Workflow | Kind | Sessions | Calls | Steps | Errors | Data tier | Test priority |
| - | -------- | ---- | -------: | ----: | ----: | -----: | --------- | ------------- |
| 1 | Account Overview & Transaction History | action | 34 | 225 | 5 | 1.3% | restricted | high |
| 2 | Fund Deposit | action | 23 | 43 | 1 | 27.9% | restricted | high |
| 3 | Fund Transfer & Verification | action | 20 | 104 | 5 | 7.7% | restricted | high |
| 4 | Login & Account Dashboard | action | 12 | 36 | 3 | 0.0% | restricted | high |
| 5 | Registration Availability Check | journey | 12 | 24 | 2 | 0.0% | confidential | medium |
| 6 | User Registration | action | 12 | 12 | 1 | 0.0% | restricted | high |
| 7 | Transaction & Balance Check | action | 11 | 37 | 3 | 10.8% | restricted | high |
| 8 | Transaction Creation & History Review | action | 11 | 22 | 2 | 0.0% | confidential | medium |
| 9 | User Authentication | action | 9 | 9 | 1 | 88.9% | restricted | high |
| 10 | Fund Transfer Initiation | action | 8 | 8 | 1 | 12.5% | confidential | high |
| 11 | Account Creation & Review | action | 7 | 35 | 5 | 0.0% | restricted | medium |
| 12 | New Account Setup | action | 6 | 18 | 3 | 0.0% | restricted | medium |
| 13 | Login & Profile View | action | 2 | 4 | 2 | 0.0% | restricted | medium |
| 14 | Statement Export | action | 2 | 2 | 1 | 0.0% | restricted | low |

## Workflow detail

### 1. Account Overview & Transaction History

User logs in and navigates through their profile, account list, specific account balance, and transaction history to review their financial status.

Test priority **high** — Covers the primary user journey for account monitoring and transaction review, which is critical for daily app usage.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`
4. `GET /api/accounts/{id}/balance`
5. `GET /api/transactions`

Data classes touched: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 2. Fund Deposit

User initiates a direct deposit transaction into a specific account.

Test priority **high** — Direct deposits are a fundamental banking operation with high user volume and financial impact.

Steps:
1. `POST /api/transactions/deposit`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 3. Fund Transfer & Verification

User creates a new transaction and immediately verifies the updated account balances and transaction records.

Test priority **high** — Covers the critical path for executing and confirming fund movements, essential for financial accuracy.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`
4. `GET /api/accounts/{id}`
5. `GET /api/transactions`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 4. Login & Account Dashboard

User authenticates and views their profile and list of associated accounts.

Test priority **high** — Represents the standard entry point and dashboard view for most authenticated users.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`

Data classes touched: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 5. Registration Availability Check

System validates the availability of a chosen username and email address before account creation.

Test priority **medium** — Important for user onboarding UX but does not complete registration or handle funds.

Steps:
1. `GET /api/users/check-username`
2. `GET /api/users/check-email`

Data classes touched: `free_text` (confidential)

### 6. User Registration

User submits credentials to create a new account in the system.

Test priority **high** — Account creation is a mandatory prerequisite for all other features and directly impacts user acquisition.

Steps:
1. `POST /api/users/register`

Data classes touched: `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `identifier` (internal), `timestamp` (internal)

### 7. Transaction & Balance Check

User initiates a transaction and immediately checks the updated account list and specific balance.

Test priority **high** — Combines transaction execution with immediate balance verification, a critical path for user trust.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 8. Transaction Creation & History Review

User creates a new transaction and reviews the updated transaction history list.

Test priority **medium** — Covers transaction execution and history but lacks immediate balance/account verification steps.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/transactions`

Data classes touched: `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 9. User Authentication

User submits credentials to authenticate and receive an access token.

Test priority **high** — Authentication is the gateway to all protected features and must be highly reliable.

Steps:
1. `POST /api/users/login`

Data classes touched: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal)

### 10. Fund Transfer Initiation

User submits a request to create a new financial transaction between accounts.

Test priority **high** — Directly handles monetary movements, making it critical for system integrity and user funds.

Steps:
1. `POST /api/transactions/create`

Data classes touched: `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 11. Account Creation & Review

User creates a new account and subsequently views the updated account list, details, balance, and transaction history.

Test priority **medium** — Important for account management but less frequent than daily login or transaction flows.

Steps:
1. `POST /api/accounts`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`
4. `GET /api/accounts/{id}`
5. `GET /api/transactions`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 12. New Account Setup

User creates a new account and immediately verifies its listing and initial balance.

Test priority **medium** — Covers account provisioning but is a secondary workflow compared to transactions and login.

Steps:
1. `POST /api/accounts`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes touched: `bank_account` (restricted), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 13. Login & Profile View

User authenticates and retrieves their personal profile information.

Test priority **medium** — Standard post-login action but lower session volume suggests it is a secondary or infrequent path.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`

Data classes touched: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `timestamp` (internal)

### 14. Statement Export

User requests an export of their account statement for a specific account.

Test priority **low** — Statement exports are typically infrequent administrative tasks with lower impact on core daily operations.

Steps:
1. `POST /api/accounts/{id}/export-statement`

Data classes touched: `bank_account` (restricted), `identifier` (internal), `money` (confidential), `timestamp` (internal)

## Endpoint health

| Endpoint | Calls | Errors | Status codes | Data tier |
| -------- | ----: | -----: | ------------ | --------- |
| `POST /api/transactions/deposit` | 23 | 52.2% | 400 x12, 201 x11 | confidential |
| `POST /api/users/login` | 57 | 14.0% | 200 x49, 401 x7, 503 x1 | restricted |
| `GET /api/accounts/{id}/balance` | 107 | 12.2% | 200 x94, 404 x12, 503 x1 | restricted |
| `GET /api/accounts` | 114 | 7.0% | 200 x106, 401 x8 | restricted |
| `GET /api/users/profile` | 49 | 2.0% | 200 x48, 503 x1 | confidential |
| `POST /api/transactions/create` | 50 | 2.0% | 201 x49, 503 x1 | confidential |
| `GET /api/transactions` | 100 | 1.0% | 200 x99, 503 x1 | confidential |
| `GET /api/accounts/{id}` | 42 | 0.0% | 200 x42 | restricted |
| `POST /api/accounts` | 13 | 0.0% | 201 x13 | restricted |
| `GET /api/users/check-username` | 12 | 0.0% | 200 x12 | confidential |
| `GET /api/users/check-email` | 12 | 0.0% | 200 x12 | confidential |
| `POST /api/users/register` | 12 | 0.0% | 201 x12 | restricted |
| `POST /api/accounts/{id}/export-statement` | 2 | 0.0% | 200 x2 | restricted |
| `POST /api/transactions/withdraw` | 1 | 0.0% | 201 x1 | confidential |

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

Endpoints seen in traffic but not part of any named workflow:
- `POST /api/transactions/withdraw`

# Traffic classifier run

Source: `sample/inbound.jsonl.gz`  
Window: 2026-08-06T20:00:12.438851+00:00 to 2026-08-06T20:29:57.566930+00:00  
Calls: 3826 across 14 endpoints, 292 distinct identities, 320 sessions  

Identity resolved from: token 3253, payload 517, none 56 (56 uncorrelated calls excluded from sessions)

## Workflows

| # | Workflow | Kind | Sessions | Calls | Steps | Errors | Data tier | Test priority |
| - | -------- | ---- | -------: | ----: | ----: | -----: | --------- | ------------- |
| 1 | Account Overview & Transaction History | action | 259 | 1718 | 5 | 1.4% | restricted | high |
| 2 | Fund Deposit | action | 183 | 415 | 1 | 24.8% | restricted | high |
| 3 | Transfer & Verification | action | 105 | 538 | 5 | 3.7% | restricted | high |
| 4 | Quick Transfer & Balance Check | action | 72 | 241 | 3 | 10.4% | restricted | medium |
| 5 | Transaction Creation & History Review | action | 70 | 140 | 2 | 0.0% | confidential | medium |
| 6 | User Registration | action | 58 | 58 | 1 | 1.7% | restricted | high |
| 7 | Account Creation & Verification | action | 57 | 215 | 3 | 0.0% | restricted | high |
| 8 | Login & Account Dashboard | action | 56 | 168 | 3 | 0.0% | restricted | high |
| 9 | Registration Availability Check | journey | 56 | 112 | 2 | 0.0% | confidential | medium |
| 10 | Standalone Transaction Creation | action | 53 | 53 | 1 | 3.8% | confidential | medium |
| 11 | User Authentication | action | 27 | 27 | 1 | 88.9% | restricted | high |
| 12 | Statement Export | action | 23 | 23 | 1 | 4.3% | restricted | low |
| 13 | Fund Withdrawal & History Check | action | 11 | 42 | 2 | 9.5% | restricted | high |
| 14 | Login & Profile View | action | 3 | 6 | 2 | 0.0% | restricted | low |
| 15 | Standalone Withdrawal | action | 2 | 2 | 1 | 0.0% | confidential | medium |

## Workflow detail

### 1. Account Overview & Transaction History

User logs in, views their profile, checks account balances, and reviews recent transaction history.

Test priority **high** — High session volume covers the core post-login navigation and financial overview path essential for daily app usage.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`
4. `GET /api/accounts/{id}/balance`
5. `GET /api/transactions`

Data classes touched: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 2. Fund Deposit

User initiates a direct deposit transaction into a specified account.

Test priority **high** — Critical financial operation with high usage; failures directly impact user funds and trust.

Steps:
1. `POST /api/transactions/deposit`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 3. Transfer & Verification

User creates a new transaction and immediately verifies updated account balances and transaction records.

Test priority **high** — Covers the complete transaction lifecycle including verification, which is essential for financial accuracy and reconciliation.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`
4. `GET /api/accounts/{id}`
5. `GET /api/transactions`

Data classes touched: `bank_account` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 4. Quick Transfer & Balance Check

User initiates a transaction and immediately checks the updated account balances.

Test priority **medium** — Frequently used but lacks full transaction history verification, making it slightly less critical than comprehensive verification flows.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 5. Transaction Creation & History Review

User creates a new transaction and immediately reviews the updated transaction list.

Test priority **medium** — Covers transaction creation and history but skips account balance verification, making it moderately critical for regression.

Steps:
1. `POST /api/transactions/create`
2. `GET /api/transactions`

Data classes touched: `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 6. User Registration

User creates a new account by providing email, username, and password.

Test priority **high** — Essential onboarding path; failures block all subsequent workflows and new user acquisition.

Steps:
1. `POST /api/users/register`

Data classes touched: `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `identifier` (internal), `timestamp` (internal)

### 7. Account Creation & Verification

User opens a new account and immediately verifies its creation and initial balance.

Test priority **high** — Core feature for financial services with significant usage; critical for proper account setup.

Steps:
1. `POST /api/accounts`
2. `GET /api/accounts`
3. `GET /api/accounts/{id}/balance`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 8. Login & Account Dashboard

User authenticates and navigates to view their profile and linked accounts.

Test priority **high** — Represents the primary post-login navigation path with high session volume and broad coverage.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`
3. `GET /api/accounts`

Data classes touched: `auth_token` (confidential), `bank_account` (restricted), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 9. Registration Availability Check

User verifies the availability of a desired username and email address before registering.

Test priority **medium** — Important for UX during onboarding but failures only delay registration rather than block core banking functions.

Steps:
1. `GET /api/users/check-username`
2. `GET /api/users/check-email`

Data classes touched: `free_text` (confidential)

### 10. Standalone Transaction Creation

User initiates a new transaction without immediate verification steps.

Test priority **medium** — Frequently used but incomplete without balance/history checks, making it moderately critical for regression.

Steps:
1. `POST /api/transactions/create`

Data classes touched: `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 11. User Authentication

User authenticates to the system using credentials.

Test priority **high** — Absolute prerequisite for all other actions; any failure completely blocks user access.

Steps:
1. `POST /api/users/login`

Data classes touched: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal)

### 12. Statement Export

User requests and generates a downloadable statement for a specific account.

Test priority **low** — Niche feature with low session count and non-critical to core daily banking operations.

Steps:
1. `POST /api/accounts/{id}/export-statement`

Data classes touched: `bank_account` (restricted), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 13. Fund Withdrawal & History Check

User initiates a withdrawal and immediately reviews the updated transaction list.

Test priority **high** — Directly impacts user funds and requires accurate transaction recording and history updates.

Steps:
1. `POST /api/transactions/withdraw`
2. `GET /api/transactions`

Data classes touched: `bank_account` (restricted), `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

### 14. Login & Profile View

User authenticates and immediately views their personal profile information.

Test priority **low** — Minimal usage and limited scope compared to full dashboard flows, indicating low regression risk.

Steps:
1. `POST /api/users/login`
2. `GET /api/users/profile`

Data classes touched: `auth_token` (confidential), `credential` (restricted), `credentials_hint` (internal), `email` (confidential), `free_text` (confidential), `identifier` (internal), `timestamp` (internal)

### 15. Standalone Withdrawal

User initiates a fund withdrawal without immediate verification steps.

Test priority **medium** — Impacts funds but has very low session count, suggesting niche or infrequent use.

Steps:
1. `POST /api/transactions/withdraw`

Data classes touched: `free_text` (confidential), `identifier` (internal), `money` (confidential), `timestamp` (internal)

## Endpoint health

| Endpoint | Calls | Errors | Status codes | Data tier |
| -------- | ----: | -----: | ------------ | --------- |
| `POST /api/transactions/deposit` | 183 | 46.5% | 201 x98, 400 x83, 500 x2 | confidential |
| `GET /api/accounts/{id}/balance` | 723 | 11.9% | 200 x637, 404 x83, 500 x2, 503 x1 | restricted |
| `GET /api/accounts` | 752 | 7.7% | 200 x694, 401 x56, 500 x1, 503 x1 | restricted |
| `POST /api/users/login` | 347 | 7.2% | 200 x322, 401 x24, 503 x1 | restricted |
| `POST /api/accounts/{id}/export-statement` | 23 | 4.3% | 200 x22, 503 x1 | restricted |
| `POST /api/users/register` | 58 | 1.7% | 201 x57, 503 x1 | restricted |
| `POST /api/transactions/create` | 301 | 0.7% | 201 x299, 503 x1, 500 x1 | confidential |
| `GET /api/users/profile` | 321 | 0.3% | 200 x320, 503 x1 | confidential |
| `GET /api/transactions` | 692 | 0.3% | 200 x690, 503 x1, 500 x1 | confidential |
| `GET /api/accounts/{id}` | 244 | 0.0% | 200 x244 | restricted |
| `POST /api/accounts` | 57 | 0.0% | 201 x57 | restricted |
| `GET /api/users/check-username` | 56 | 0.0% | 200 x56 | confidential |
| `GET /api/users/check-email` | 56 | 0.0% | 200 x56 | confidential |
| `POST /api/transactions/withdraw` | 13 | 0.0% | 201 x13 | confidential |

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

| Endpoint | Field | Observations with free text |
| -------- | ----- | --------------------------: |
| `GET /api/transactions` | `[].description` | 2 |
| `POST /api/transactions/create` | `description` | 2 |

## Coverage gaps

Every observed endpoint appears in at least one workflow.

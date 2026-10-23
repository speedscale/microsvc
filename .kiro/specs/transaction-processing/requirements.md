# Requirements — Transaction Processing

`backend/transactions-service` (Java / Spring Boot) handles deposits, withdrawals and
transfers. Each is screened by fraud-service (gRPC), moves money via accounts-service
(REST), is stored in Postgres, fans out to Stripe/PayPal/ComplyAdvantage, and emits an
event to Kafka `transaction-events` for notification-service.

## Requirements

### 1. Create a transaction
1. The service SHALL expose `POST /api/transactions/deposit`, `/withdraw`, `/transfer`
   and `/create` (dispatches on `type`); success returns `201` with `TransactionResponse`.
2. Validation failure SHALL return `400` with a map of field errors. A transfer to the
   same account, or without `toAccountId`, is invalid (the same-account check is missing
   on `/create`: tasks.md task 1).
3. The acting user SHALL come from the validated JWT, not the request body.

### 2. Fraud screening
1. Before validating accounts or changing balances, the service SHALL call fraud-service
   over gRPC with account id, user id, amount, transaction type and merchant category.
2. `approved = false` SHALL reject the transaction with the returned reason.
3. If fraud-service is unavailable the service SHALL fail open (treat as approved) and
   record the reason.

### 3. Ownership and balance
1. The service SHALL verify account ownership via accounts-service (both accounts for a
   transfer), forwarding the caller's authorization.
2. A withdrawal or transfer above the available balance SHALL be rejected.

### 4. Atomic balance updates
1. Balance mutations SHALL run under per-account locks; transfers take both locks in
   sorted account-id order.
2. If crediting the destination fails, the service SHALL attempt to roll back the debit.
3. Any failed step SHALL persist the record as `FAILED` and surface the error; success
   persists `COMPLETED` with `processed_at`. (Not met today: see tasks.md task 2.)

### 5. Payments and compliance
1. After completion the service SHALL call Stripe, PayPal and ComplyAdvantage
   concurrently; failures are logged and SHALL NOT fail the transaction.
2. A transfer SHALL also run a synchronous ComplyAdvantage screen that blocks on matches
   or non-low risk.

### 6. Events
After completion the service SHALL publish to `transaction-events`, keyed by transaction
id, with transaction id, account id, user id, amount, type, status and timestamp. Publish
is fire-and-forget; a broker outage SHALL NOT fail the transaction.

### 7. Query
`GET /api/transactions` SHALL return the authenticated user's transactions, filtered by
`accountId` when supplied.

### 8. Persistence and observability
1. Transactions are stored in `transactions_service.transactions`, with schema managed by
   Flyway and validated by Hibernate.
2. Each handler SHALL open an OTel span with user id, account id, amount, type and
   transaction id; deposit, withdraw and transfer amount histograms SHALL be recorded.

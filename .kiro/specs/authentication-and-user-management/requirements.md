# Requirements — Authentication & User Management

Covers `backend/user-service` (.NET 8, registration/login/profile/token issuance),
`backend/api-gateway` (Spring Cloud Gateway, edge JWT enforcement) and `frontend`
(Next.js, token handling). Note: the README calls user-service Java; the implementation is
.NET 8 and this spec follows the implementation.

## Requirements

### 1. Registration
1. `POST /api/users/register` with username, email, password SHALL create the user and
   return `201` with the user summary (id, username, email, roles, createdAt, updatedAt).
2. Duplicate username or email SHALL return `409`; other invalid input SHALL return `400`.
3. Passwords SHALL be stored only as BCrypt hashes. New users get role `USER`.
4. Identity-verification calls (Socure, Jumio, HIBP) SHALL run asynchronously; their
   failures are logged and SHALL NOT block registration.

### 2. Login and token issuance
1. `POST /api/users/login` with valid username-or-email and password SHALL return `200`
   with `{ token, type: "Bearer", id, username, email, roles }`.
2. Invalid credentials SHALL return `401` without revealing which field was wrong.
3. The JWT SHALL be HMAC-SHA256 signed, carry `sub` (username), `userId` and `roles`, and
   expire after 24 hours.

### 3. Profile and availability
1. `GET /api/users/profile` with a valid bearer token SHALL return `200`; a missing,
   malformed or invalid token SHALL return `401`.
2. `GET /api/users/check-username` and `/check-email` SHALL report availability without
   authentication.

### 4. Gateway edge authentication
1. Public (no token): `/api/users/register`, `/login`, `/check-username`, `/check-email`,
   `/api/*-service/health`, `/api/healthz`.
2. Any other route without a valid, unexpired token SHALL return `401`.
3. Routes: `/api/users/**` → user-service, `/api/accounts/**` → accounts-service,
   `/api/transactions/**` → transactions-service.

### 5. Cross-service token compatibility
1. All services SHALL validate JWTs with the same HMAC secret from `JWT_SECRET`. Built-in
   fallbacks differ between .NET and Java, so an unset `JWT_SECRET` makes every
   user-service token fail with `401` downstream.
2. Downstream Java services SHALL derive `sub`, `userId` and `roles` from the validated
   token, never from unauthenticated headers or the request body.

### 6. Frontend token handling
1. The frontend SHALL store the JWT in a cookie and attach it as `Authorization: Bearer`
   via axios interceptors; it SHALL remove it on logout and treat an expired token as
   unauthenticated.
2. Known gap: the cookie is JS-readable and not HttpOnly/Secure (see tasks 1–3).

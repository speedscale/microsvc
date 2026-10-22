# Tasks — Authentication & User Management

Registration, login, profile, availability checks, gateway enforcement and routing,
cross-service validation and frontend token handling are implemented (requirements 1–6).
Open hardening items, independent of each other:

- [ ] 1. Store the token in a server-set `HttpOnly`, `Secure`, `SameSite` cookie via a
  Next.js route; stop reading the raw JWT from client JS. _Req 6.2_
- [ ] 2. Make all services share one `JWT_SECRET` default, or fail fast when unset, and
  reject the built-in default outside local development. _Req 5.1_
- [x] 3. Gateway forwards the validated `userId` as `X-User-Id` (client values overwritten),
  which the per-user rate limiter keys on. Downstream services keep re-validating the
  token. _Req 4.3, 5.2_

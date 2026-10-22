# Tasks — Authentication & User Management

Registration, login, profile, availability checks, gateway enforcement and routing,
cross-service validation and frontend token handling are implemented (requirements 1–6).
Gateway enforcement is implemented except malformed `Authorization` headers (task 4).
Open hardening items, independent of each other:

- [ ] 1. Store the token in a server-set `HttpOnly`, `Secure`, `SameSite` cookie via a
  Next.js route; stop reading the raw JWT from client JS. _Req 6.2_
- [ ] 2. Make all services share one `JWT_SECRET` default, or fail fast when unset, and
  reject the built-in default outside local development. _Req 5.1_
- [x] 3. Gateway forwards the validated `userId` as `X-User-Id` (client values overwritten),
  which the per-user rate limiter keys on. Downstream services keep re-validating the
  token. _Req 4.3, 5.2_
- [ ] 4. Return `401`, not a server error, for a malformed `Authorization` header:
  `AuthenticationFilter.getAuthHeader()` calls `substring(7)` on a value shorter than 7
  characters or with the wrong scheme. Check for the `Bearer ` prefix first. _Req 4.2_

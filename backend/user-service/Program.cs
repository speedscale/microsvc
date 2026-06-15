using Microsoft.EntityFrameworkCore;
using Prometheus;
using UserServiceDotnet.Data;
using UserServiceDotnet.Services;

var builder = WebApplication.CreateBuilder(args);

var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "banking-postgres";
var dbPort = Environment.GetEnvironmentVariable("DB_PORT") ?? "5432";
var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "banking";
var dbUser = Environment.GetEnvironmentVariable("DB_USERNAME") ?? Environment.GetEnvironmentVariable("DB_USER") ?? "user_service";
var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "";

var connectionString = $"Host={dbHost};Port={dbPort};Database={dbName};Username={dbUser};Password={dbPassword}";

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

builder.Services.AddHttpClient<IdentityVerificationService>();
builder.Services.AddScoped<UserService>();
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
    });

var app = builder.Build();

// Bootstrap the user_service table on startup so the service works against any fresh
// database without relying on an external seed/migration job. The Java services
// self-migrate via Flyway; this is the .NET equivalent. (EnsureCreated() is unusable
// here because the banking_app database is shared and already exists, so it no-ops
// even when this table is missing.)
//
// NOTE: we do NOT issue CREATE SCHEMA here. The user_service schema is provisioned by
// the database init (cluster postgres configmap / compose database/init), and Postgres
// requires CREATE-on-database privilege for CREATE SCHEMA even with IF NOT EXISTS — which
// the least-privilege app role (user_service_user) does not (and should not) have. The
// role does have CREATE on the existing schema, so CREATE TABLE alone succeeds.
//
// Idempotent, retried for Postgres readiness, and best-effort: if it can't run (e.g. a
// mocked Postgres in CI with no recorded response, or a missing schema) we log and
// continue rather than crash — a real Postgres gets the table; a mock answers directly.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    const string ddl = @"
        CREATE TABLE IF NOT EXISTS user_service.users (
            id            BIGSERIAL PRIMARY KEY,
            username      VARCHAR(50)  UNIQUE NOT NULL,
            email         VARCHAR(100) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            roles         VARCHAR(50)  NOT NULL DEFAULT 'USER',
            created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
            updated_at    TIMESTAMP
        );";
    Exception? lastError = null;
    for (var attempt = 1; attempt <= 8; attempt++)
    {
        try { db.Database.ExecuteSqlRaw(ddl); lastError = null; break; }
        catch (Exception ex)
        {
            lastError = ex;
            Console.WriteLine($"[startup] user_service schema bootstrap attempt {attempt}/8 failed: {ex.Message}");
            System.Threading.Thread.Sleep(2000);
        }
    }
    if (lastError != null)
        Console.WriteLine("[startup] user_service schema bootstrap did not complete; continuing startup (real Postgres should already be migrated, mocked Postgres answers queries directly).");
}

app.UseHttpMetrics();
app.MapControllers();
app.MapGet("/actuator/health", () => Results.Ok(new { status = "UP" }));
app.MapMetrics("/actuator/prometheus");

app.Run();

using Microsoft.EntityFrameworkCore;
using Prometheus;
using System.Text.RegularExpressions;
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

// Seed the named customer pool the load client logs into. The simulator reuses
// these accounts for most sessions, so fresh databases need matching users.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var simPassword = Environment.GetEnvironmentVariable("SIM_USER_PASSWORD") ?? "SimUser123!";
    var simCount = int.TryParse(Environment.GetEnvironmentVariable("SIM_USER_COUNT"), out var c) ? c : 1000;
    var simHash = BCrypt.Net.BCrypt.HashPassword(simPassword);
    try
    {
        var seeded = 0;
        using var tx = db.Database.BeginTransaction();
        for (var i = 1; i <= simCount; i++)
        {
            var user = SeedUserProfiles.Build(i);
            seeded += db.Database.ExecuteSqlInterpolated($@"
                INSERT INTO user_service.users (username, email, password_hash, roles, created_at, updated_at)
                VALUES ({user.Username}, {user.Email}, {simHash}, 'USER', NOW(), NOW())
                ON CONFLICT (username) DO NOTHING;");
        }
        tx.Commit();

        if (seeded > 0)
            Console.WriteLine($"[startup] seeded {seeded} named customer accounts for the load client.");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[startup] customer account seed skipped: {ex.Message} (continuing; a healthy Postgres seeds on next startup).");
    }
}

app.UseHttpMetrics();
app.MapControllers();
app.MapGet("/actuator/health", () => Results.Ok(new { status = "UP" }));
app.MapMetrics("/actuator/prometheus");

app.Run();

static class SeedUserProfiles
{
    public static (string Username, string Email) Build(int index)
    {
        var locale = LocaleCycle[(Math.Max(1, index) - 1) % LocaleCycle.Length];
        var names = NamesByLocale[locale];
        var firstName = names.First[(index * 7) % names.First.Length];
        var lastName = names.Last[(index * 11) % names.Last.Length];
        var padded = index.ToString().PadLeft(3, '0');
        var username = $"{Slug(firstName)}.{Slug(lastName)}.{padded}";
        return (username, $"{username}@northbridge.example");
    }

    static string Slug(string value) =>
        Regex.Replace(value.ToLowerInvariant(), "[^a-z0-9]+", "");

    static readonly string[] LocaleCycle = new[]
    {
        "en-US", "en-US", "en-US", "en-US", "en-US",
        "en-GB", "en-CA", "en-AU",
        "es-MX", "es-ES", "fr-FR", "de-DE", "it-IT",
        "nl-NL", "sv-SE", "pl-PL", "pt-BR",
        "ja-JP", "ko-KR", "zh-CN",
    };

    static readonly Dictionary<string, (string[] First, string[] Last)> NamesByLocale = new()
    {
        ["en-US"] = (
            new[] { "Olivia", "Emma", "Ava", "Sophia", "Mia", "Charlotte", "Amelia", "Harper", "Liam", "Noah", "Ethan", "Lucas" },
            new[] { "Smith", "Johnson", "Williams", "Brown", "Miller", "Davis", "Wilson", "Anderson", "Taylor", "Martin", "Thompson", "Clark" }),
        ["en-GB"] = (
            new[] { "Oliver", "George", "Harry", "Jack", "Arthur", "Isla", "Freya", "Grace", "Amelia", "Florence" },
            new[] { "Smith", "Jones", "Taylor", "Brown", "Williams", "Wilson", "Evans", "Thomas", "Roberts", "Walker" }),
        ["en-CA"] = (
            new[] { "Liam", "Noah", "William", "Lucas", "Benjamin", "Emma", "Olivia", "Charlotte", "Sophia", "Ava" },
            new[] { "Smith", "Brown", "Tremblay", "Martin", "Roy", "Wilson", "Taylor", "Campbell", "Anderson", "Lee" }),
        ["en-AU"] = (
            new[] { "Oliver", "Noah", "Jack", "Henry", "Leo", "Charlotte", "Olivia", "Amelia", "Isla", "Mia" },
            new[] { "Smith", "Jones", "Williams", "Brown", "Wilson", "Taylor", "Martin", "Anderson", "Thompson", "White" }),
        ["es-MX"] = (
            new[] { "Sofia", "Valentina", "Camila", "Regina", "Mateo", "Santiago", "Diego", "Emiliano", "Lucia", "Daniel" },
            new[] { "Garcia", "Hernandez", "Lopez", "Martinez", "Gonzalez", "Perez", "Rodriguez", "Sanchez", "Ramirez", "Torres" }),
        ["es-ES"] = (
            new[] { "Lucia", "Sofia", "Martina", "Maria", "Julia", "Hugo", "Martin", "Lucas", "Leo", "Daniel" },
            new[] { "Garcia", "Rodriguez", "Gonzalez", "Fernandez", "Lopez", "Martinez", "Sanchez", "Perez", "Gomez", "Martin" }),
        ["fr-FR"] = (
            new[] { "Camille", "Lea", "Chloe", "Manon", "Emma", "Hugo", "Louis", "Gabriel", "Arthur", "Jules" },
            new[] { "Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau" }),
        ["de-DE"] = (
            new[] { "Emma", "Mia", "Hannah", "Sofia", "Lina", "Ben", "Paul", "Leon", "Finn", "Felix" },
            new[] { "Muller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Hoffmann", "Schulz" }),
        ["it-IT"] = (
            new[] { "Giulia", "Sofia", "Aurora", "Alice", "Ginevra", "Leonardo", "Francesco", "Lorenzo", "Alessandro", "Mattia" },
            new[] { "Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco" }),
        ["nl-NL"] = (
            new[] { "Emma", "Tess", "Sophie", "Julia", "Mila", "Daan", "Sem", "Lucas", "Finn", "Levi" },
            new[] { "DeVries", "Jansen", "Bakker", "Visser", "Smit", "Meijer", "DeBoer", "Mulder", "Bos", "Vos" }),
        ["sv-SE"] = (
            new[] { "Alice", "Elsa", "Maja", "Lilly", "Ella", "Oscar", "Lucas", "William", "Liam", "Noah" },
            new[] { "Andersson", "Johansson", "Karlsson", "Nilsson", "Eriksson", "Larsson", "Olsson", "Persson", "Svensson", "Gustafsson" }),
        ["pl-PL"] = (
            new[] { "Zofia", "Hanna", "Julia", "Maja", "Laura", "Jan", "Antoni", "Jakub", "Aleksander", "Szymon" },
            new[] { "Nowak", "Kowalski", "Wisniewski", "Wojcik", "Kowalczyk", "Kaminski", "Lewandowski", "Zielinski", "Szymanski", "Dabrowski" }),
        ["pt-BR"] = (
            new[] { "Ana", "Beatriz", "Mariana", "Laura", "Isabela", "Joao", "Pedro", "Lucas", "Miguel", "Gabriel" },
            new[] { "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes" }),
        ["ja-JP"] = (
            new[] { "Yuki", "Haruto", "Sota", "Yuto", "Ren", "Hina", "Sakura", "Aoi", "Mei", "Rin" },
            new[] { "Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato" }),
        ["ko-KR"] = (
            new[] { "SeoJun", "DoYun", "HaJun", "JiHo", "MinJun", "SeoYeon", "HaYoon", "JiA", "SeoAh", "HaEun" },
            new[] { "Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim" }),
        ["zh-CN"] = (
            new[] { "Wei", "Fang", "Jing", "Lei", "Ming", "Hao", "Chen", "Liang", "Mei", "Yan" },
            new[] { "Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Wu", "Zhou" }),
    };
}

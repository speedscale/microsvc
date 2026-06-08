using Microsoft.EntityFrameworkCore;
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

app.MapControllers();
app.MapGet("/actuator/health", () => Results.Ok(new { status = "UP" }));

app.Run();

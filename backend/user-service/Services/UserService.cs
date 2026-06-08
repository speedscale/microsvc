using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using UserServiceDotnet.Data;
using UserServiceDotnet.Models;

namespace UserServiceDotnet.Services;

public class UserService
{
    private readonly AppDbContext _db;
    private readonly IdentityVerificationService _idVerification;
    private readonly ILogger<UserService> _logger;
    private readonly string _jwtSecret;
    private readonly TimeSpan _jwtExpiry = TimeSpan.FromHours(24);

    public UserService(
        AppDbContext db,
        IdentityVerificationService idVerification,
        ILogger<UserService> logger,
        IConfiguration configuration)
    {
        _db = db;
        _idVerification = idVerification;
        _logger = logger;
        _jwtSecret = configuration["JWT_SECRET"] ?? "demo-jwt-secret-key-for-banking-app";
    }

    public async Task<User> RegisterUser(string username, string email, string password)
    {
        _logger.LogInformation("Registering new user: {Username}", username);

        if (await _db.Users.AnyAsync(u => u.Username == username))
            throw new InvalidOperationException("Username already exists");

        if (await _db.Users.AnyAsync(u => u.Email == email))
            throw new InvalidOperationException("Email already exists");

        var user = new User
        {
            Username = username,
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            Roles = "USER",
            CreatedAt = DateTime.UtcNow
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();
        _logger.LogInformation("User registered successfully: {Username}", username);

        try
        {
            _idVerification.VerifyIdentityAsync(user.Email, user.Id);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Identity verification dispatch failed for user: {Username}", username);
        }

        return user;
    }

    public async Task<(User User, string Token)> Authenticate(string usernameOrEmail, string password)
    {
        _logger.LogInformation("Authenticating user: {UsernameOrEmail}", usernameOrEmail);

        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Username == usernameOrEmail || u.Email == usernameOrEmail);

        if (user == null || !BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
        {
            _logger.LogError("Invalid credentials for: {UsernameOrEmail}", usernameOrEmail);
            throw new InvalidOperationException("Invalid credentials");
        }

        var token = GenerateToken(user.Username, user.Id, user.Roles);
        _logger.LogInformation("User authenticated successfully: {Username}", user.Username);
        return (user, token);
    }

    public async Task<User> GetProfile(string username)
    {
        _logger.LogInformation("Getting profile for user: {Username}", username);

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == username);
        if (user == null)
            throw new InvalidOperationException("User not found");

        return user;
    }

    public async Task<bool> UsernameExists(string username) =>
        await _db.Users.AnyAsync(u => u.Username == username);

    public async Task<bool> EmailExists(string email) =>
        await _db.Users.AnyAsync(u => u.Email == email);

    public string GenerateToken(string username, long userId, string roles)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSecret));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, username),
            new Claim("userId", userId.ToString()),
            new Claim("roles", roles)
        };

        var token = new JwtSecurityToken(
            claims: claims,
            expires: DateTime.UtcNow.Add(_jwtExpiry),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public ClaimsPrincipal? ValidateToken(string token)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSecret));
        var handler = new JwtSecurityTokenHandler();

        try
        {
            return handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = key,
                ValidateIssuer = false,
                ValidateAudience = false,
                ClockSkew = TimeSpan.Zero
            }, out _);
        }
        catch
        {
            return null;
        }
    }
}

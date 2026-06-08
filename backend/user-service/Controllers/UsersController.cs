using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using UserServiceDotnet.Services;

namespace UserServiceDotnet.Controllers;

[ApiController]
[Route("api/users")]
public class UsersController : ControllerBase
{
    private readonly UserService _userService;
    private readonly ILogger<UsersController> _logger;

    public UsersController(UserService userService, ILogger<UsersController> logger)
    {
        _userService = userService;
        _logger = logger;
    }

    public record RegisterRequest(string Username, string Email, string Password, bool? GenerateDemoData);
    public record LoginRequest(string UsernameOrEmail, string Password);

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            _logger.LogInformation("Registration request for username: {Username}", request.Username);

            var user = await _userService.RegisterUser(request.Username, request.Email, request.Password);

            return StatusCode(201, new
            {
                id = user.Id,
                username = user.Username,
                email = user.Email,
                roles = user.Roles,
                createdAt = user.CreatedAt,
                updatedAt = user.UpdatedAt
            });
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("already exists"))
        {
            _logger.LogError("Registration failed: {Message}", ex.Message);
            return Conflict(new { success = false, message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError("Registration failed: {Message}", ex.Message);
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        try
        {
            _logger.LogInformation("Login request for: {UsernameOrEmail}", request.UsernameOrEmail);

            var (user, token) = await _userService.Authenticate(request.UsernameOrEmail, request.Password);

            return Ok(new
            {
                token,
                type = "Bearer",
                id = user.Id,
                username = user.Username,
                email = user.Email,
                roles = user.Roles
            });
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("Invalid credentials"))
        {
            _logger.LogError("Authentication failed: {Message}", ex.Message);
            return Unauthorized(new { success = false, message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError("Authentication failed: {Message}", ex.Message);
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    [HttpGet("profile")]
    public async Task<IActionResult> GetProfile()
    {
        var authHeader = Request.Headers.Authorization.ToString();
        if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer "))
            return Unauthorized(new { success = false, message = "Missing or invalid token" });

        var token = authHeader["Bearer ".Length..];
        var principal = _userService.ValidateToken(token);
        if (principal == null)
            return Unauthorized(new { success = false, message = "Invalid token" });

        var username = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value
                    ?? principal.FindFirst("sub")?.Value;
        if (username == null)
            return Unauthorized(new { success = false, message = "Invalid token claims" });

        try
        {
            _logger.LogInformation("Profile request for user: {Username}", username);
            var user = await _userService.GetProfile(username);

            return Ok(new
            {
                success = true,
                message = "Profile retrieved successfully",
                data = new
                {
                    id = user.Id,
                    username = user.Username,
                    email = user.Email,
                    roles = user.Roles,
                    createdAt = user.CreatedAt,
                    updatedAt = user.UpdatedAt
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError("Profile retrieval failed: {Message}", ex.Message);
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    [HttpGet("check-username")]
    public async Task<IActionResult> CheckUsername([FromQuery] string username)
    {
        _logger.LogDebug("Checking username availability: {Username}", username);
        var exists = await _userService.UsernameExists(username);

        return Ok(new
        {
            success = true,
            available = !exists,
            message = exists ? "Username is not available" : "Username is available"
        });
    }

    [HttpGet("check-email")]
    public async Task<IActionResult> CheckEmail([FromQuery] string email)
    {
        _logger.LogDebug("Checking email availability: {Email}", email);
        var exists = await _userService.EmailExists(email);

        return Ok(new
        {
            success = true,
            available = !exists,
            message = exists ? "Email is not available" : "Email is available"
        });
    }
}

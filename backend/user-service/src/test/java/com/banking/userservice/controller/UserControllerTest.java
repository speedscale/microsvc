package com.banking.userservice.controller;

import com.banking.userservice.dto.UserLoginRequest;
import com.banking.userservice.dto.UserLoginResponse;
import com.banking.userservice.dto.UserRegistrationRequest;
import com.banking.userservice.entity.User;
import com.banking.userservice.service.UserService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.LongCounterBuilder;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanBuilder;
import io.opentelemetry.api.trace.Tracer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
@WebMvcTest(value = UserController.class, excludeAutoConfiguration = {
    org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration.class,
    org.springframework.boot.autoconfigure.security.servlet.SecurityFilterAutoConfiguration.class
})
@ContextConfiguration(classes = {UserController.class, UserControllerTest.TestConfig.class})
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;
    private UserRegistrationRequest registrationRequest;
    private UserLoginRequest loginRequest;
    private UserLoginResponse loginResponse;

    @BeforeEach
    void setUp() {
        testUser = new User();
        testUser.setId(1L);
        testUser.setUsername("testuser");
        testUser.setEmail("test@example.com");
        testUser.setPasswordHash("hashedPassword");
        testUser.setRoles("USER");
        testUser.setCreatedAt(LocalDateTime.now());
        testUser.setUpdatedAt(LocalDateTime.now());

        registrationRequest = new UserRegistrationRequest();
        registrationRequest.setUsername("testuser");
        registrationRequest.setEmail("test@example.com");
        registrationRequest.setPassword("password123");

        loginRequest = new UserLoginRequest();
        loginRequest.setUsernameOrEmail("testuser");
        loginRequest.setPassword("password123");

        loginResponse = new UserLoginResponse();
        loginResponse.setToken("jwt-token");
        loginResponse.setId(1L);
        loginResponse.setUsername("testuser");
        loginResponse.setEmail("test@example.com");
        loginResponse.setRoles("USER");
    }

    @Test
    void registerUser_Success() throws Exception {
        // Arrange
        when(userService.registerUser(any(UserRegistrationRequest.class))).thenReturn(testUser);

        // Act & Assert
        mockMvc.perform(post("/api/users/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registrationRequest)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.username").value("testuser"))
                .andExpect(jsonPath("$.email").value("test@example.com"))
                .andExpect(jsonPath("$.roles").value("USER"));

        verify(userService, times(1)).registerUser(any(UserRegistrationRequest.class));
    }

    @Test
    void registerUser_InvalidInput() throws Exception {
        // Arrange
        registrationRequest.setUsername(""); // Invalid username

        // Act & Assert
        mockMvc.perform(post("/api/users/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registrationRequest)))
                .andExpect(status().isBadRequest());

        verify(userService, never()).registerUser(any(UserRegistrationRequest.class));
    }

    @Test
    void registerUser_UsernameExists() throws Exception {
        // Arrange
        when(userService.registerUser(any(UserRegistrationRequest.class)))
                .thenThrow(new RuntimeException("Username already exists"));

        // Act & Assert
        mockMvc.perform(post("/api/users/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registrationRequest)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value("Username already exists"));

        verify(userService, times(1)).registerUser(any(UserRegistrationRequest.class));
    }

    @Test
    void loginUser_Success() throws Exception {
        // Arrange
        when(userService.authenticateUser(any(UserLoginRequest.class))).thenReturn(loginResponse);

        // Act & Assert
        mockMvc.perform(post("/api/users/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("jwt-token"))
                .andExpect(jsonPath("$.username").value("testuser"))
                .andExpect(jsonPath("$.email").value("test@example.com"));

        verify(userService, times(1)).authenticateUser(any(UserLoginRequest.class));
    }

    @Test
    void loginUser_InvalidCredentials() throws Exception {
        // Arrange
        when(userService.authenticateUser(any(UserLoginRequest.class)))
                .thenThrow(new RuntimeException("Invalid credentials"));

        // Act & Assert
        mockMvc.perform(post("/api/users/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid credentials"));

        verify(userService, times(1)).authenticateUser(any(UserLoginRequest.class));
    }

    @Test
    void checkUsername_Available() throws Exception {
        // Arrange
        when(userService.usernameExists(anyString())).thenReturn(false);

        // Act & Assert
        mockMvc.perform(get("/api/users/check-username")
                .param("username", "newuser"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(true));

        verify(userService, times(1)).usernameExists("newuser");
    }

    @Test
    void checkUsername_NotAvailable() throws Exception {
        // Arrange
        when(userService.usernameExists(anyString())).thenReturn(true);

        // Act & Assert
        mockMvc.perform(get("/api/users/check-username")
                .param("username", "existinguser"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(false));

        verify(userService, times(1)).usernameExists("existinguser");
    }

    @Profile("!test")
    static class TestConfig {
        
        @Bean
        @Primary
        public Tracer tracer() {
            Tracer mockTracer = mock(Tracer.class);
            SpanBuilder mockSpanBuilder = mock(SpanBuilder.class);
            Span mockSpan = mock(Span.class);
            
            lenient().when(mockTracer.spanBuilder(anyString())).thenReturn(mockSpanBuilder);
            lenient().when(mockSpanBuilder.startSpan()).thenReturn(mockSpan);
            lenient().when(mockSpan.setAttribute(anyString(), anyString())).thenReturn(mockSpan);
            lenient().when(mockSpan.setAttribute(anyString(), any(Long.class))).thenReturn(mockSpan);
            lenient().when(mockSpan.setAttribute(anyString(), any(Boolean.class))).thenReturn(mockSpan);
            
            return mockTracer;
        }
        
        @Bean
        @Primary
        public Meter meter() {
            Meter mockMeter = mock(Meter.class);
            LongCounterBuilder mockBuilder = mock(LongCounterBuilder.class);
            LongCounter mockCounter = mock(LongCounter.class);
            
            lenient().when(mockMeter.counterBuilder(anyString())).thenReturn(mockBuilder);
            lenient().when(mockBuilder.setDescription(anyString())).thenReturn(mockBuilder);
            lenient().when(mockBuilder.setUnit(anyString())).thenReturn(mockBuilder);
            lenient().when(mockBuilder.build()).thenReturn(mockCounter);
            
            return mockMeter;
        }
    }

    @Test
    void checkEmail_Available() throws Exception {
        // Arrange
        when(userService.emailExists(anyString())).thenReturn(false);

        // Act & Assert
        mockMvc.perform(get("/api/users/check-email")
                .param("email", "new@example.com"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(true));

        verify(userService, times(1)).emailExists("new@example.com");
    }

    @Test
    void checkEmail_NotAvailable() throws Exception {
        // Arrange
        when(userService.emailExists(anyString())).thenReturn(true);

        // Act & Assert
        mockMvc.perform(get("/api/users/check-email")
                .param("email", "existing@example.com"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(false));

        verify(userService, times(1)).emailExists("existing@example.com");
    }

}
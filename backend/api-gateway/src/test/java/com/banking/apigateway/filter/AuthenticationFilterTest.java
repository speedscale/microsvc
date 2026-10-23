package com.banking.apigateway.filter;

import com.banking.apigateway.config.RouterValidator;
import com.banking.apigateway.util.JwtUtil;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.impl.DefaultClaims;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthenticationFilterTest {

    @Mock
    private JwtUtil jwtUtil;

    @Spy
    private RouterValidator routerValidator = new RouterValidator();

    @Mock
    private GatewayFilterChain chain;

    @InjectMocks
    private AuthenticationFilter filter;

    @Test
    void forwardsValidatedUserIdOverClientSuppliedHeader() {
        Claims claims = new DefaultClaims(Map.of("userId", 42));
        when(jwtUtil.isInvalid("tok")).thenReturn(false);
        when(jwtUtil.getAllClaimsFromToken("tok")).thenReturn(claims);
        when(chain.filter(any())).thenReturn(Mono.empty());

        ServerWebExchange exchange = MockServerWebExchange.from(
                MockServerHttpRequest.get("/api/accounts")
                        .header("Authorization", "Bearer tok")
                        .header("X-User-Id", "spoofed")
                        .build());

        filter.filter(exchange, chain).block();

        ArgumentCaptor<ServerWebExchange> forwarded = ArgumentCaptor.forClass(ServerWebExchange.class);
        verify(chain).filter(forwarded.capture());
        assertEquals("42", forwarded.getValue().getRequest().getHeaders().getFirst("X-User-Id"));
    }
}

package com.banking.apigateway.filter;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.List;

@Component
public class TracePropagationFilter implements GlobalFilter, Ordered {

    private static final Logger logger = LoggerFactory.getLogger(TracePropagationFilter.class);

    // Trace context headers to propagate
    private static final List<String> TRACE_HEADERS = List.of(
        "traceparent",
        "tracestate",
        "b3",
        "x-b3-traceid",
        "x-b3-spanid",
        "x-b3-sampled"
    );

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        ServerHttpRequest.Builder requestBuilder = request.mutate();

        // Log incoming trace headers for debugging
        TRACE_HEADERS.forEach(headerName -> {
            List<String> headerValues = request.getHeaders().get(headerName);
            if (headerValues != null && !headerValues.isEmpty()) {
                logger.debug("Propagating trace header {}: {}", headerName, headerValues.get(0));
            }
        });

        // The trace headers are automatically propagated by Spring Cloud Gateway
        // when using the TraceIdInjectionFilter, but we log them for debugging
        return chain.filter(exchange);
    }

    @Override
    public int getOrder() {
        // Run early in the filter chain, but after authentication
        return Ordered.HIGHEST_PRECEDENCE + 100;
    }
} 
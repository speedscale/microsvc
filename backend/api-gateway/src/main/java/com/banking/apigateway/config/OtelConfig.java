package com.banking.apigateway.config;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.trace.Tracer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Lazy;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.ExchangeFilterFunction;

@Configuration
@ConditionalOnProperty(name = "otel.traces.exporter", havingValue = "otlp", matchIfMissing = false)
public class OtelConfig {

    @Value("${otel.exporter.otlp.endpoint:http://localhost:4317}")
    private String otlpEndpoint;

    @Bean
    @Lazy
    public Meter meter(OpenTelemetry openTelemetry) {
        return openTelemetry.getMeter("api-gateway-meter");
    }

    @Bean
    @Lazy
    public Tracer tracer(OpenTelemetry openTelemetry) {
        return openTelemetry.getTracer("api-gateway-tracer");
    }

    @Bean
    @Lazy
    public LongCounter requestsCounter(Meter meter) {
        return meter
                .counterBuilder("gateway.requests.total")
                .setDescription("Total number of API Gateway requests")
                .setUnit("1")
                .build();
    }

    @Bean
    @Lazy
    public LongCounter authenticatedRequestsCounter(Meter meter) {
        return meter
                .counterBuilder("gateway.requests.authenticated")
                .setDescription("Number of authenticated requests")
                .setUnit("1")
                .build();
    }

    @Bean
    @Lazy
    public LongCounter unauthenticatedRequestsCounter(Meter meter) {
        return meter
                .counterBuilder("gateway.requests.unauthenticated")
                .setDescription("Number of unauthenticated requests")
                .setUnit("1")
                .build();
    }

    @Bean
    @Lazy
    public LongCounter errorsCounter(Meter meter) {
        return meter
                .counterBuilder("gateway.errors.total")
                .setDescription("Total number of API Gateway errors")
                .setUnit("1")
                .build();
    }

    @Bean
    public WebClient.Builder webClientBuilder() {
        return WebClient.builder()
                .filter(tracePropagationFilter());
    }

    @Bean
    public ExchangeFilterFunction tracePropagationFilter() {
        return (request, next) -> {
            // This filter ensures trace context is propagated to downstream services
            // Spring Cloud Gateway automatically handles trace propagation when configured
            return next.exchange(request);
        };
    }
} 
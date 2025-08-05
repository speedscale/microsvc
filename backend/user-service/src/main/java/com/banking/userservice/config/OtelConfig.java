package com.banking.userservice.config;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.trace.Tracer;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Lazy;

@Configuration
public class OtelConfig {

    @Bean
    @Lazy
    public Meter meter(OpenTelemetry openTelemetry) {
        return openTelemetry.getMeter("user-service-meter");
    }

    @Bean
    @Lazy
    public Tracer tracer(OpenTelemetry openTelemetry) {
        return openTelemetry.getTracer("user-service-tracer");
    }

    @Bean
    @Lazy
    public LongCounter registeredUsersCounter(Meter meter) {
        return meter
                .counterBuilder("users.registered")
                .setDescription("Number of registered users")
                .setUnit("1")
                .build();
    }

    @Bean
    @Lazy
    public LongCounter successfulLoginsCounter(Meter meter) {
        return meter
                .counterBuilder("users.login.success")
                .setDescription("Number of successful logins")
                .setUnit("1")
                .build();
    }

    @Bean
    @Lazy
    public LongCounter failedLoginsCounter(Meter meter) {
        return meter
                .counterBuilder("users.login.failure")
                .setDescription("Number of failed logins")
                .setUnit("1")
                .build();
    }
}
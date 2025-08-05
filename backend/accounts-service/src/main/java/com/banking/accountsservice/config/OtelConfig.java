package com.banking.accountsservice.config;

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
        return openTelemetry.getMeter("accounts-service-meter");
    }

    @Bean
    @Lazy
    public Tracer tracer(OpenTelemetry openTelemetry) {
        return openTelemetry.getTracer("accounts-service-tracer");
    }

    @Bean
    @Lazy
    public LongCounter createdAccountsCounter(Meter meter) {
        return meter
                .counterBuilder("accounts.created")
                .setDescription("Number of created accounts")
                .setUnit("1")
                .build();
    }
}
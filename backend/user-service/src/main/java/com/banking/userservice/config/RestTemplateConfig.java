package com.banking.userservice.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

import java.time.Duration;

@Configuration
public class RestTemplateConfig {

    @Bean
    @ConditionalOnProperty(name = "otel.traces.exporter", havingValue = "otlp", matchIfMissing = false)
    public RestTemplate restTemplate() {
        // Use RestTemplateBuilder for automatic trace propagation
        return new RestTemplateBuilder()
                .setConnectTimeout(Duration.ofSeconds(5))
                .setReadTimeout(Duration.ofSeconds(10))
                .build();
    }

    @Bean
    @ConditionalOnProperty(name = "otel.traces.exporter", havingValue = "otlp", matchIfMissing = true)
    public RestTemplate restTemplateFallback() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5000); // 5 seconds
        factory.setReadTimeout(10000);   // 10 seconds
        return new RestTemplate(factory);
    }
} 
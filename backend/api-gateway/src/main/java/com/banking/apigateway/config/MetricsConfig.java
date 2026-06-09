package com.banking.apigateway.config;

import io.micrometer.common.KeyValues;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.reactive.observation.DefaultServerRequestObservationConvention;
import org.springframework.http.server.reactive.observation.ServerRequestObservationContext;
import org.springframework.http.server.reactive.observation.ServerRequestObservationConvention;

import java.util.regex.Pattern;

/**
 * Replaces UNKNOWN uri tags with the matched route path pattern so
 * Prometheus queries can group errors by endpoint even when a gateway
 * filter short-circuits the response (e.g. AuthenticationFilter 401).
 */
@Configuration
public class MetricsConfig {

    private static final Pattern TRAILING_ID = Pattern.compile("/\\d+(/|$)");

    @Bean
    ServerRequestObservationConvention gatewayUriConvention() {
        return new DefaultServerRequestObservationConvention() {
            @Override
            public KeyValues getLowCardinalityKeyValues(ServerRequestObservationContext context) {
                KeyValues kv = super.getLowCardinalityKeyValues(context);
                boolean hasUnknown = kv.stream()
                        .anyMatch(k -> "uri".equals(k.getKey())
                                && ("UNKNOWN".equals(k.getValue()) || "NOT_FOUND".equals(k.getValue())));
                if (!hasUnknown) {
                    return kv;
                }
                String path = context.getCarrier().getURI().getPath();
                if (path == null || path.isEmpty()) {
                    return kv;
                }
                String normalized = TRAILING_ID.matcher(path).replaceAll("/{id}$1");
                KeyValues result = KeyValues.empty();
                for (var entry : kv) {
                    if ("uri".equals(entry.getKey())) {
                        result = result.and(entry.getKey(), normalized);
                    } else {
                        result = result.and(entry);
                    }
                }
                return result;
            }
        };
    }
}

package com.banking.demo;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
public class PartnerApi {
    private final RestTemplate client;
    private final String url;

    public PartnerApi(RestTemplateBuilder builder, @Value("${demo.partner-url}") String url) {
        this.client = builder.setConnectTimeout(Duration.ofSeconds(2))
                .setReadTimeout(Duration.ofSeconds(2)).build();
        this.url = url;
    }

    public String assess(long account) {
        JsonNode response = client.getForObject(url + "/assessment/" + account, JsonNode.class);
        String decision = response == null ? "" : response.path("decision").asText();
        if (!DECISIONS.contains(decision)) {
            throw new IllegalStateException("Invalid partner decision");
        }
        return decision;
    }

    private static final java.util.Set<String> DECISIONS = java.util.Set.of("APPROVED", "REVIEW");
}

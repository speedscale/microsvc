package com.banking.userservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

@Service
public class IdentityVerificationService {

    private static final Logger logger = LoggerFactory.getLogger(IdentityVerificationService.class);

    @Autowired
    private RestTemplate restTemplate;

    @Value("${SOCURE_API_KEY:mock-socure-key}")
    private String socureApiKey;

    @Value("${JUMIO_API_TOKEN:mock-jumio-token}")
    private String jumioApiToken;

    @Value("${HIBP_API_KEY:mock-hibp-key}")
    private String hibpApiKey;

    public void verifyIdentityAsync(String email, Long userId) {
        logger.info("Starting identity verification for user {} ({})", userId, email);

        CompletableFuture<Void> socure = CompletableFuture.runAsync(() -> callSocure(email))
                .orTimeout(5, TimeUnit.SECONDS)
                .exceptionally(ex -> { logger.warn("Socure check failed: {}", ex.getMessage()); return null; });

        CompletableFuture<Void> jumio = CompletableFuture.runAsync(() -> callJumio(email, userId))
                .orTimeout(5, TimeUnit.SECONDS)
                .exceptionally(ex -> { logger.warn("Jumio check failed: {}", ex.getMessage()); return null; });

        CompletableFuture<Void> hibp = CompletableFuture.runAsync(() -> callHibp(email))
                .orTimeout(5, TimeUnit.SECONDS)
                .exceptionally(ex -> { logger.warn("HIBP check failed: {}", ex.getMessage()); return null; });

        CompletableFuture.allOf(socure, jumio, hibp)
                .thenRun(() -> logger.info("Identity verification complete for user {}", userId));
    }

    private void callSocure(String email) {
        logger.info("Calling Socure ID+ for email: {}", email);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Authorization", "SocureApiKey " + socureApiKey);

        Map<String, Object> body = Map.of(
                "modules", new String[]{"emailrisk"},
                "email", email
        );

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);
        restTemplate.postForEntity("https://sandbox.socure.com/api/3.0/EmailAuthScore", entity, String.class);
        logger.info("Socure ID+ call completed for email: {}", email);
    }

    private void callJumio(String email, Long userId) {
        logger.info("Calling Jumio for user: {}", userId);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Authorization", "Bearer " + jumioApiToken);

        Map<String, Object> body = Map.of(
                "customerInternalReference", "apex-user-" + userId,
                "userReference", email
        );

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);
        restTemplate.postForEntity("https://netverify.com/api/v4/initiate", entity, String.class);
        logger.info("Jumio call completed for user: {}", userId);
    }

    private void callHibp(String email) {
        logger.info("Calling HIBP for email: {}", email);
        HttpHeaders headers = new HttpHeaders();
        headers.set("hibp-api-key", hibpApiKey);
        headers.set("user-agent", "ApexBanking/1.0");

        HttpEntity<Void> entity = new HttpEntity<>(headers);
        restTemplate.exchange(
                "https://haveibeenpwned.com/api/v3/breachedaccount/" + email,
                HttpMethod.GET,
                entity,
                String.class
        );
        logger.info("HIBP call completed for email: {}", email);
    }
}

package com.banking.accountsservice.service;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;

@Service
public class FinancialDataService {

    private static final Logger logger = LoggerFactory.getLogger(FinancialDataService.class);
    private static final Duration TIMEOUT = Duration.ofSeconds(5);

    @Value("${PLAID_CLIENT_ID:test_client_id}")
    private String plaidClientId;

    @Value("${PLAID_SECRET:test_secret}")
    private String plaidSecret;

    @Value("${EXCHANGE_RATES_APP_ID:demo_app_id}")
    private String exchangeRatesAppId;

    @Value("${MOODYS_API_KEY:demo_moodys_key}")
    private String moodysApiKey;

    @Value("${MOODYS_API_URL:https://api.ratings.moodys.com/research/v1/ratings?identifier=test}")
    private String moodysApiUrl;

    private HttpClient httpClient;

    @PostConstruct
    void init() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(TIMEOUT)
                .build();
        logger.info("FinancialDataService initialized");
    }

    public void enrichAsync(String accountNumber) {
        CompletableFuture<Void> plaid = fetchPlaidBalance(accountNumber);
        CompletableFuture<Void> exchange = fetchExchangeRates();
        CompletableFuture<Void> moodys = fetchMoodysRating();

        CompletableFuture.allOf(plaid, exchange, moodys)
                .whenComplete((v, ex) -> {
                    if (ex != null) {
                        logger.warn("Financial enrichment completed with errors", ex);
                    } else {
                        logger.info("Financial enrichment completed for account {}", accountNumber);
                    }
                });
    }

    private CompletableFuture<Void> fetchPlaidBalance(String accountNumber) {
        String body = "{\"access_token\":\"access-sandbox-" + accountNumber + "\"}";
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://sandbox.plaid.com/accounts/balance/get"))
                .timeout(TIMEOUT)
                .header("Content-Type", "application/json")
                .header("PLAID-CLIENT-ID", plaidClientId)
                .header("PLAID-SECRET", plaidSecret)
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(resp -> logger.info("Plaid balance response: status={}", resp.statusCode()))
                .exceptionally(ex -> {
                    logger.warn("Plaid balance call failed: {}", ex.getMessage());
                    return null;
                });
    }

    private CompletableFuture<Void> fetchExchangeRates() {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://openexchangerates.org/api/latest.json?app_id=" + exchangeRatesAppId + "&base=USD"))
                .timeout(TIMEOUT)
                .GET()
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(resp -> logger.info("Exchange rates response: status={}", resp.statusCode()))
                .exceptionally(ex -> {
                    logger.warn("Exchange rates call failed: {}", ex.getMessage());
                    return null;
                });
    }

    private CompletableFuture<Void> fetchMoodysRating() {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(moodysApiUrl))
                .timeout(TIMEOUT)
                .header("Authorization", "Bearer " + moodysApiKey)
                .GET()
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(resp -> logger.info("Moody's rating response: status={}", resp.statusCode()))
                .exceptionally(ex -> {
                    logger.warn("Moody's rating call failed: {}", ex.getMessage());
                    return null;
                });
    }
}

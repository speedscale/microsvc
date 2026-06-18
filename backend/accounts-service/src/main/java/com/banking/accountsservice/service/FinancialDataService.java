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

    @Value("${EXCHANGE_RATES_APP_ID:placeholder_app_id}")
    private String exchangeRatesAppId;

    @Value("${MOODYS_API_KEY:placeholder_moodys_key}")
    private String moodysApiKey;

    @Value("${MOODYS_API_URL:https://api.ratings.moodys.com/research/v1/ratings?identifier=test}")
    private String moodysApiUrl;

    private HttpClient httpClient;

    // Cached Plaid sandbox access token (acquired via public_token create+exchange).
    private volatile String plaidAccessToken;

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
        return ensurePlaidAccessToken().thenCompose(token -> {
            if (token == null) {
                logger.warn("Plaid access token unavailable; skipping balance call");
                return CompletableFuture.completedFuture(null);
            }
            String body = "{\"access_token\":\"" + token + "\"}";
            HttpRequest request = plaidRequest("/accounts/balance/get", body);
            return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                    .thenAccept(resp -> logger.info("Plaid balance response: status={}", resp.statusCode()))
                    .exceptionally(ex -> {
                        logger.warn("Plaid balance call failed: {}", ex.getMessage());
                        return null;
                    });
        });
    }

    // Plaid sandbox tokens are not constructible: create a public_token then exchange it
    // for an access_token. Cached and reused across accounts.
    private CompletableFuture<String> ensurePlaidAccessToken() {
        String cached = plaidAccessToken;
        if (cached != null) {
            return CompletableFuture.completedFuture(cached);
        }
        String createBody = "{\"institution_id\":\"ins_109508\",\"initial_products\":[\"transactions\"]}";
        HttpRequest createReq = plaidRequest("/sandbox/public_token/create", createBody);
        return httpClient.sendAsync(createReq, HttpResponse.BodyHandlers.ofString())
                .thenCompose(createResp -> {
                    String publicToken = extractJsonString(createResp.body(), "public_token");
                    if (publicToken == null) {
                        logger.warn("Plaid public_token create failed: status={}", createResp.statusCode());
                        return CompletableFuture.completedFuture((String) null);
                    }
                    HttpRequest exchangeReq = plaidRequest("/item/public_token/exchange",
                            "{\"public_token\":\"" + publicToken + "\"}");
                    return httpClient.sendAsync(exchangeReq, HttpResponse.BodyHandlers.ofString())
                            .thenApply(exchangeResp -> {
                                String token = extractJsonString(exchangeResp.body(), "access_token");
                                if (token != null) {
                                    plaidAccessToken = token;
                                    logger.info("Plaid sandbox access token acquired");
                                } else {
                                    logger.warn("Plaid token exchange failed: status={}", exchangeResp.statusCode());
                                }
                                return token;
                            });
                })
                .exceptionally(ex -> {
                    logger.warn("Plaid token setup failed: {}", ex.getMessage());
                    return null;
                });
    }

    private HttpRequest plaidRequest(String path, String body) {
        return HttpRequest.newBuilder()
                .uri(URI.create("https://sandbox.plaid.com" + path))
                .timeout(TIMEOUT)
                .header("Content-Type", "application/json")
                .header("PLAID-CLIENT-ID", plaidClientId)
                .header("PLAID-SECRET", plaidSecret)
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();
    }

    // Minimal "key":"value" string extractor — avoids pulling in a JSON dependency here.
    private static String extractJsonString(String json, String key) {
        if (json == null) {
            return null;
        }
        String needle = "\"" + key + "\"";
        int k = json.indexOf(needle);
        if (k < 0) {
            return null;
        }
        int colon = json.indexOf(':', k + needle.length());
        if (colon < 0) {
            return null;
        }
        int q1 = json.indexOf('"', colon + 1);
        if (q1 < 0) {
            return null;
        }
        int q2 = json.indexOf('"', q1 + 1);
        if (q2 < 0) {
            return null;
        }
        return json.substring(q1 + 1, q2);
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

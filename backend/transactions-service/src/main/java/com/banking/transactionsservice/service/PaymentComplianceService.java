package com.banking.transactionsservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;

@Service
public class PaymentComplianceService {

    private static final Logger logger = LoggerFactory.getLogger(PaymentComplianceService.class);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(5);

    @Value("${payment.stripe.api-key:sk_test_dummy_key_for_ebpf_capture}")
    private String stripeApiKey;

    @Value("${payment.paypal.access-token:A21AAJ_dummy_paypal_token_for_ebpf}")
    private String paypalAccessToken;

    @Value("${payment.comply.api-key:comply_test_dummy_key_for_ebpf}")
    private String complyApiKey;

    private HttpClient httpClient;

    @PostConstruct
    void init() {
        httpClient = HttpClient.newBuilder()
                .connectTimeout(REQUEST_TIMEOUT)
                .build();
    }

    public void fanOutPaymentAndCompliance(Long transactionId, String transactionType, Double amount) {
        logger.info("Fanning out payment/compliance calls for transaction {}", transactionId);

        CompletableFuture<Void> stripe = callStripe(transactionId, amount);
        CompletableFuture<Void> paypal = callPayPal(transactionId, amount);
        CompletableFuture<Void> comply = callComplyAdvantage(transactionId);

        CompletableFuture.allOf(stripe, paypal, comply)
                .whenComplete((v, ex) -> {
                    if (ex != null) {
                        logger.warn("One or more payment/compliance calls failed for transaction {}: {}",
                                transactionId, ex.getMessage());
                    } else {
                        logger.info("All payment/compliance calls completed for transaction {}", transactionId);
                    }
                });
    }

    private CompletableFuture<Void> callStripe(Long transactionId, Double amount) {
        String body = "amount=" + amount.intValue() + "&currency=usd&payment_method_types[]=card";

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://api.stripe.com/v1/payment_intents"))
                .timeout(REQUEST_TIMEOUT)
                .header("Authorization", "Bearer " + stripeApiKey)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(resp -> logger.info("Stripe response for tx {}: status={}", transactionId, resp.statusCode()))
                .exceptionally(ex -> {
                    logger.warn("Stripe call failed for tx {}: {}", transactionId, ex.getMessage());
                    return null;
                });
    }

    private CompletableFuture<Void> callPayPal(Long transactionId, Double amount) {
        String body = """
                {"intent":"CAPTURE","purchase_units":[{"amount":{"currency_code":"USD","value":"%s"}}]}"""
                .formatted(String.format("%.2f", amount));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://api-m.sandbox.paypal.com/v2/checkout/orders"))
                .timeout(REQUEST_TIMEOUT)
                .header("Authorization", "Bearer " + paypalAccessToken)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(resp -> logger.info("PayPal response for tx {}: status={}", transactionId, resp.statusCode()))
                .exceptionally(ex -> {
                    logger.warn("PayPal call failed for tx {}: {}", transactionId, ex.getMessage());
                    return null;
                });
    }

    private CompletableFuture<Void> callComplyAdvantage(Long transactionId) {
        String body = """
                {"search_term":"Transaction %d","search_type":"individual","fuzziness":0.6}"""
                .formatted(transactionId);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://api.complyadvantage.com/searches"))
                .timeout(REQUEST_TIMEOUT)
                .header("Authorization", "Token " + complyApiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(resp -> logger.info("ComplyAdvantage response for tx {}: status={}", transactionId, resp.statusCode()))
                .exceptionally(ex -> {
                    logger.warn("ComplyAdvantage call failed for tx {}: {}", transactionId, ex.getMessage());
                    return null;
                });
    }
}

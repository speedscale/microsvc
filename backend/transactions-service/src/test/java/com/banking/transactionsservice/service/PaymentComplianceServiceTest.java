package com.banking.transactionsservice.service;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PaymentComplianceServiceTest {

    private HttpServer server;
    private PaymentComplianceService service;

    @BeforeEach
    void setUp() throws Exception {
        server = HttpServer.create(new InetSocketAddress(0), 0);
        server.start();

        service = new PaymentComplianceService();
        ReflectionTestUtils.setField(service, "complyApiKey", "test-key");
        ReflectionTestUtils.setField(service, "complyBaseUrl", "http://127.0.0.1:" + server.getAddress().getPort());
        service.init();
    }

    @AfterEach
    void tearDown() {
        server.stop(0);
    }

    @Test
    void verifyTransferComplianceRequiresReviewForUnknownRisk() {
        respondWith("""
                {"content":{"data":{"risk_level":"unknown","total_matches":0}},"status":"success"}""");

        RuntimeException exception = assertThrows(RuntimeException.class, () ->
                service.verifyTransferCompliance(1L, 2L));

        assertTrue(exception.getMessage().contains("Compliance screening requires review"));
    }

    @Test
    void verifyTransferComplianceAllowsLowRiskWithNoMatches() {
        respondWith("""
                {"content":{"data":{"risk_level":"low","total_matches":0}},"status":"success"}""");

        assertDoesNotThrow(() -> service.verifyTransferCompliance(1L, 2L));
    }

    private void respondWith(String body) {
        server.createContext("/searches", exchange -> {
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
    }
}

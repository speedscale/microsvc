package com.banking.demo;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class LedgerTest {
    private final PartnerApi partner = mock(PartnerApi.class);
    private final Ledger ledger = new Ledger(new ObjectMapper(), partner);
    private ConsumerRecord<String, String> record(String key, String body) {
        return new ConsumerRecord<>("test-transactions", 0, 7, key, body);
    }
    private static final String EVENT = """
            {"transaction_id":1,"account_id":70668,"amount":3.33,"transaction_type":"DEPOSIT","status":"COMPLETED"}
            """;

    @Test void preservesBusinessOutcomeAndKafkaIdentity() throws Exception {
        when(partner.assess(70668)).thenReturn("APPROVED");
        ledger.consume(record("1", EVENT));
        assertThat(ledger.snapshot().toString()).contains("outcome=COMPLETED", "offset=7", "partition=0");
        assertThat(ledger.snapshot()).containsEntry("deliveries", 1).containsEntry("duplicates", 0);
    }

    @Test void deduplicatesByTransactionIdentity() throws Exception {
        when(partner.assess(70668)).thenReturn("APPROVED");
        ledger.consume(record("1", EVENT));
        ledger.consume(record("1", EVENT));
        assertThat(ledger.snapshot()).containsEntry("deliveries", 2).containsEntry("duplicates", 1);
        verify(partner, times(1)).assess(70668);
    }

    @Test void sendsUnapprovedEventsForReview() throws Exception {
        when(partner.assess(70668)).thenReturn("REVIEW");
        ledger.consume(record("1", EVENT));
        assertThat(ledger.snapshot().toString()).contains("outcome=REVIEW");
    }

    @Test void rejectsInvalidIdentityAndPayload() {
        for (String body : new String[] {EVENT.replace("\"amount\":3.33", "\"amount\":-1"),
                EVENT.replace("\"status\":\"COMPLETED\"", "\"status\":null"),
                EVENT.replace("\"account_id\":70668", "\"account_id\":null"),
                EVENT.replace("\"transaction_type\":\"DEPOSIT\"", "\"transaction_type\":null"),
                EVENT.replace("\"transaction_id\":1", "\"transaction_id\":0")}) {
            assertThatThrownBy(() -> ledger.consume(record("1", body))).isInstanceOf(IllegalArgumentException.class);
        }
        assertThatThrownBy(() -> ledger.consume(record("2", EVENT))).isInstanceOf(IllegalArgumentException.class);
        assertThat(ledger.snapshot()).containsEntry("rejected", 6);
        verifyNoInteractions(partner);
    }

    @Test void refusesMalformedJsonAndDoesNotStorePartnerFailures() {
        assertThatThrownBy(() -> ledger.consume(record("1", "invalid"))).isInstanceOf(Exception.class);
        when(partner.assess(70668)).thenThrow(new IllegalStateException("Partner unavailable"));
        assertThatThrownBy(() -> ledger.consume(record("1", EVENT))).hasMessage("Partner unavailable");
        assertThat(ledger.snapshot().get("entries")).asList().isEmpty();
    }
}

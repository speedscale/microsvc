package com.banking.demo;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class Ledger {
    private final ObjectMapper mapper;
    private final PartnerApi partner;
    private final Map<Long, Map<String, Object>> entries = new LinkedHashMap<>();
    private int deliveries;
    private int duplicates;
    private int rejected;
    private static final int CAPACITY = 1000;

    public Ledger(ObjectMapper mapper, PartnerApi partner) {
        this.mapper = mapper;
        this.partner = partner;
    }

    @KafkaListener(id = "ledger", groupId = "${spring.kafka.consumer.group-id}",
            topics = "${demo.topic}", autoStartup = "${demo.listener-enabled}")
    public synchronized void consume(ConsumerRecord<String, String> record) throws Exception {
        JsonNode event = mapper.readTree(record.value());
        long id = event.path("transaction_id").asLong(-1);
        if (id < 1 || !Long.toString(id).equals(record.key())
                || !event.path("amount").isNumber() || event.path("amount").asDouble() <= 0
                || !event.path("account_id").isIntegralNumber()
                || !event.path("status").isTextual() || !event.path("transaction_type").isTextual()) {
            rejected++;
            throw new IllegalArgumentException("Invalid transaction event");
        }
        deliveries++;
        if (entries.containsKey(id)) {
            duplicates++;
            return;
        }
        if (entries.size() >= CAPACITY) {
            rejected++;
            throw new IllegalStateException("Ledger capacity reached");
        }
        String decision = partner.assess(event.path("account_id").asLong());
        String outcome = "APPROVED".equals(decision) ? event.path("status").asText() : "REVIEW";
        Map<String, Object> entry = new LinkedHashMap<>();
        entry.put("transactionId", id);
        entry.put("key", record.key());
        entry.put("topic", record.topic());
        entry.put("partition", record.partition());
        entry.put("offset", record.offset());
        entry.put("event", event);
        entry.put("partnerDecision", decision);
        entry.put("outcome", outcome);
        entries.put(id, entry);
    }

    public synchronized Map<String, Object> snapshot() {
        return Map.of("entries", new ArrayList<>(entries.values()), "deliveries", deliveries,
                "duplicates", duplicates, "rejected", rejected);
    }
}

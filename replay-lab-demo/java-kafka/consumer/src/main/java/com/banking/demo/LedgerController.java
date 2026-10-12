package com.banking.demo;

import java.util.Map;
import org.springframework.kafka.config.KafkaListenerEndpointRegistry;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LedgerController {
    private final Ledger ledger;
    private final KafkaListenerEndpointRegistry registry;

    public LedgerController(Ledger ledger, KafkaListenerEndpointRegistry registry) {
        this.ledger = ledger;
        this.registry = registry;
    }

    @GetMapping("/ledger")
    public Map<String, Object> ledger() {
        return ledger.snapshot();
    }

    @GetMapping("/ready")
    public Map<String, Boolean> ready() {
        var listener = registry.getListenerContainer("ledger");
        return Map.of("assigned", listener != null && listener.isRunning()
                && listener.getAssignedPartitions() != null && !listener.getAssignedPartitions().isEmpty());
    }
}

package com.banking.transactionsservice.event;

import com.banking.transactionsservice.entity.Transaction;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class TransactionEventProducer {

    private static final Logger logger = LoggerFactory.getLogger(TransactionEventProducer.class);

    private final KafkaTemplate<String, String> kafkaTemplate;

    @Value("${kafka.topic.transactions:transaction-events}")
    private String topic;

    public TransactionEventProducer(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void publishTransactionEvent(Transaction transaction) {
        try {
            String payload = String.format(
                "{\"transaction_id\":%d,\"account_id\":%s,\"user_id\":%d,\"amount\":%.2f," +
                "\"transaction_type\":\"%s\",\"status\":\"%s\",\"timestamp\":\"%s\"}",
                transaction.getId(),
                transaction.getFromAccountId() != null
                    ? transaction.getFromAccountId().toString()
                    : transaction.getToAccountId() != null
                        ? transaction.getToAccountId().toString()
                        : "null",
                transaction.getUserId(),
                transaction.getAmount(),
                transaction.getType().name(),
                transaction.getStatus().name(),
                transaction.getProcessedAt() != null
                    ? transaction.getProcessedAt().toString()
                    : transaction.getCreatedAt().toString()
            );

            kafkaTemplate.send(topic, String.valueOf(transaction.getId()), payload);
            logger.info("Published transaction event to {}: transaction_id={}", topic, transaction.getId());
        } catch (Exception e) {
            logger.error("Failed to publish transaction event for transaction_id={}: {}",
                    transaction.getId(), e.getMessage());
            // Fire-and-forget: never rethrow so Kafka issues don't fail transactions
        }
    }
}

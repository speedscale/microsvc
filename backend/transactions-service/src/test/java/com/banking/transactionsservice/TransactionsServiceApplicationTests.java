package com.banking.transactionsservice;

import com.banking.transactionsservice.client.FraudServiceClient;
import com.banking.transactionsservice.event.TransactionEventProducer;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class TransactionsServiceApplicationTests {

    // Prevent Spring from wiring the real gRPC client and Kafka producer during context load
    @MockBean
    private FraudServiceClient fraudServiceClient;

    @MockBean
    private TransactionEventProducer transactionEventProducer;

    @Test
    void contextLoads() {
    }
}
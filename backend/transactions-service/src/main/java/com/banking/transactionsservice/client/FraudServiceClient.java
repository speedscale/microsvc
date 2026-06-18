package com.banking.transactionsservice.client;

import com.banking.transactions.grpc.FraudCheckResponse;
import com.banking.transactions.grpc.FraudCheckerGrpc;
import com.banking.transactions.grpc.TransactionRequest;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class FraudServiceClient {

    private static final Logger logger = LoggerFactory.getLogger(FraudServiceClient.class);

    @GrpcClient("fraud-service")
    private FraudCheckerGrpc.FraudCheckerBlockingStub fraudCheckerStub;

    public FraudCheckResponse checkTransaction(String accountId, String userId, double amount, String transactionType, String merchantCategory) {
        try {
            TransactionRequest request = TransactionRequest.newBuilder()
                    .setAccountId(accountId)
                    .setUserId(userId)
                    .setAmount(amount)
                    .setTransactionType(transactionType)
                    .setMerchantCategory(merchantCategory == null ? "" : merchantCategory)
                    .build();

            FraudCheckResponse response = fraudCheckerStub.checkTransaction(request);
            logger.info("Fraud check for account={} user={} type={} amount={}: approved={} risk={} reason={}",
                    accountId, userId, transactionType, amount,
                    response.getApproved(), response.getRiskScore(), response.getReason());
            return response;
        } catch (Exception e) {
            logger.warn("Fraud service unavailable for account={} user={}, failing open: {}", accountId, userId, e.getMessage());
            // Fail open so fraud service outage does not block transactions
            return FraudCheckResponse.newBuilder()
                    .setApproved(true)
                    .setRiskScore(0.0)
                    .setReason("fraud-service unavailable, fail-open")
                    .build();
        }
    }
}

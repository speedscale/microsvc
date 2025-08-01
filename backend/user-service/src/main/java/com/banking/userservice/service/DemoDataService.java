package com.banking.userservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.Random;

@Service
public class DemoDataService {

    private static final Logger logger = LoggerFactory.getLogger(DemoDataService.class);

    @Autowired
    private RestTemplate restTemplate;

    @Value("${accounts.service.url:http://localhost:8081}")
    private String accountsServiceUrl;

    @Value("${transactions.service.url:http://localhost:8082}")
    private String transactionsServiceUrl;

    private final Random random = new Random();

    public void generateDemoData(Long userId, String jwtToken) {
        logger.info("Generating demo data for user: {}", userId);
        
        try {
            // Validate JWT token before making service calls
            if (jwtToken == null || jwtToken.trim().isEmpty()) {
                logger.warn("JWT token is null or empty for user: {}", userId);
                return;
            }
            
            // Create 2 accounts
            Long checkingAccountId = createDemoAccount(userId, "CHECKING", jwtToken);
            Long savingsAccountId = createDemoAccount(userId, "SAVINGS", jwtToken);
            
            // Only generate transactions if accounts were created successfully
            if (checkingAccountId != null && savingsAccountId != null) {
                generateDemoTransactions(userId, checkingAccountId, savingsAccountId, jwtToken);
                logger.info("Demo data generated successfully for user: {}", userId);
            } else {
                logger.warn("Failed to create accounts for user: {}, skipping transaction generation", userId);
            }
        } catch (Exception e) {
            logger.error("Failed to generate demo data for user: {}", userId, e);
            // Don't throw exception to prevent cascading failures
            // Just log the error and continue
        }
    }

    private Long createDemoAccount(Long userId, String accountType, String jwtToken) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "Bearer " + jwtToken);
            headers.set("X-User-Id", userId.toString());
            
            var request = new CreateAccountRequest();
            request.setAccountType(accountType);
            request.setInitialBalance(accountType.equals("CHECKING") ? 2500.0 : 10000.0);
            request.setCurrency("USD");
            
            HttpEntity<CreateAccountRequest> entity = new HttpEntity<>(request, headers);
            
            logger.debug("Calling accounts service to create {} account for user: {}", accountType, userId);
            
            ResponseEntity<AccountResponse> response = restTemplate.exchange(
                accountsServiceUrl + "/api/accounts",
                HttpMethod.POST,
                entity,
                AccountResponse.class
            );
            
            if (response.getBody() != null) {
                logger.info("Created {} account with ID: {} for user: {}", accountType, response.getBody().getId(), userId);
                return response.getBody().getId();
            }
            
            logger.error("Failed to create {} account for user: {} - no response body", accountType, userId);
            return null;
        } catch (Exception e) {
            logger.error("Failed to create {} account for user: {}", accountType, userId, e);
            return null;
        }
    }

    private void generateDemoTransactions(Long userId, Long checkingAccountId, Long savingsAccountId, String jwtToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", "Bearer " + jwtToken);
        headers.set("X-User-Id", userId.toString());
        
        String[] transactionTypes = {"DEPOSIT", "WITHDRAWAL", "TRANSFER"};
        String[] descriptions = {
            "Salary deposit", "ATM withdrawal", "Online purchase", "Utility bill payment",
            "Restaurant payment", "Gas station", "Grocery shopping", "Coffee shop",
            "Movie tickets", "Book purchase", "Gym membership", "Phone bill"
        };
        
        for (int i = 0; i < 10; i++) {
            String type = transactionTypes[random.nextInt(transactionTypes.length)];
            String description = descriptions[random.nextInt(descriptions.length)];
            double amount = 10.0 + random.nextDouble() * 500.0; // $10 to $510
            
            var request = new CreateTransactionRequest();
            request.setAccountId(checkingAccountId);
            request.setType(type);
            request.setAmount(amount);
            request.setCurrency("USD");
            request.setDescription(description);
            
            // For transfers, set the destination account
            if (type.equals("TRANSFER")) {
                request.setToAccountId(savingsAccountId);
            }
            
            HttpEntity<CreateTransactionRequest> entity = new HttpEntity<>(request, headers);
            
            try {
                ResponseEntity<TransactionResponse> response = restTemplate.exchange(
                    transactionsServiceUrl + "/api/transactions",
                    HttpMethod.POST,
                    entity,
                    TransactionResponse.class
                );
                
                if (response.getBody() != null) {
                    logger.info("Created transaction {} for user: {}", response.getBody().getId(), userId);
                }
            } catch (Exception e) {
                logger.warn("Failed to create transaction {} for user: {}", i + 1, userId, e);
            }
        }
    }

    // DTO classes for API calls
    public static class CreateAccountRequest {
        private String accountType;
        private Double initialBalance;
        private String currency;

        public String getAccountType() { return accountType; }
        public void setAccountType(String accountType) { this.accountType = accountType; }
        public Double getInitialBalance() { return initialBalance; }
        public void setInitialBalance(Double initialBalance) { this.initialBalance = initialBalance; }
        public String getCurrency() { return currency; }
        public void setCurrency(String currency) { this.currency = currency; }
    }

    public static class AccountResponse {
        private Long id;
        private String accountNumber;
        private String accountType;
        private BigDecimal balance;
        private String currency;
        private String status;

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getAccountNumber() { return accountNumber; }
        public void setAccountNumber(String accountNumber) { this.accountNumber = accountNumber; }
        public String getAccountType() { return accountType; }
        public void setAccountType(String accountType) { this.accountType = accountType; }
        public BigDecimal getBalance() { return balance; }
        public void setBalance(BigDecimal balance) { this.balance = balance; }
        public String getCurrency() { return currency; }
        public void setCurrency(String currency) { this.currency = currency; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
    }

    public static class CreateTransactionRequest {
        private Long accountId;
        private Long toAccountId;
        private String type;
        private Double amount;
        private String currency;
        private String description;

        public Long getAccountId() { return accountId; }
        public void setAccountId(Long accountId) { this.accountId = accountId; }
        public Long getToAccountId() { return toAccountId; }
        public void setToAccountId(Long toAccountId) { this.toAccountId = toAccountId; }
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
        public Double getAmount() { return amount; }
        public void setAmount(Double amount) { this.amount = amount; }
        public String getCurrency() { return currency; }
        public void setCurrency(String currency) { this.currency = currency; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
    }

    public static class TransactionResponse {
        private Long id;
        private Long accountId;
        private String type;
        private BigDecimal amount;
        private String currency;
        private String description;
        private String status;

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public Long getAccountId() { return accountId; }
        public void setAccountId(Long accountId) { this.accountId = accountId; }
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
        public BigDecimal getAmount() { return amount; }
        public void setAmount(BigDecimal amount) { this.amount = amount; }
        public String getCurrency() { return currency; }
        public void setCurrency(String currency) { this.currency = currency; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
    }
} 
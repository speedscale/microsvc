package com.banking.accountsservice.service;

import com.banking.accountsservice.entity.Account;
import com.banking.accountsservice.repository.AccountRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import jakarta.annotation.PostConstruct;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class StatementExportService {

    private static final Logger logger = LoggerFactory.getLogger(StatementExportService.class);

    @Autowired
    private AccountRepository accountRepository;

    private S3Client s3Client;
    private String bucketName;
    private boolean configured;
    private final ObjectMapper objectMapper;

    public StatementExportService() {
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
        this.objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    @PostConstruct
    void init() {
        this.bucketName = System.getenv("AWS_S3_BUCKET");
        if (bucketName == null || bucketName.isBlank()) {
            logger.warn("AWS_S3_BUCKET not set -- statement export disabled");
            this.configured = false;
            return;
        }

        String regionStr = System.getenv("AWS_REGION");
        Region region = (regionStr != null && !regionStr.isBlank())
                ? Region.of(regionStr)
                : Region.US_EAST_1;

        this.s3Client = S3Client.builder()
                .region(region)
                .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
        this.configured = true;
        logger.info("Statement export configured: bucket={}, region={}", bucketName, region);
    }

    public boolean isConfigured() {
        return configured;
    }

    /**
     * Builds the statement document for an account. Does not touch S3, so it is
     * safe (and egress-free) to call even when no object store is configured.
     */
    public Map<String, Object> generateStatement(Long accountId, Long userId) {
        Account account = accountRepository.findByIdAndUserId(accountId, userId)
                .orElseThrow(() -> new RuntimeException("Account not found or access denied"));

        Map<String, Object> statement = new LinkedHashMap<>();
        statement.put("accountId", account.getId());
        statement.put("accountNumber", account.getAccountNumber());
        statement.put("accountType", account.getAccountType());
        statement.put("balance", account.getBalance());
        statement.put("exportedAt", LocalDateTime.now().toString());
        statement.put("userId", userId);
        return statement;
    }

    public String exportStatement(Long accountId, Long userId) {
        Map<String, Object> statement = generateStatement(accountId, userId);

        String timestamp = Instant.now().toString().replace(":", "-");
        String key = "statements/account-" + accountId + "/" + timestamp + ".json";

        try {
            byte[] payload = objectMapper.writeValueAsBytes(statement);

            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(key)
                    .contentType("application/json")
                    .build();

            s3Client.putObject(putRequest, RequestBody.fromBytes(payload));
            logger.info("Exported statement to s3://{}/{}", bucketName, key);
            return key;
        } catch (Exception e) {
            logger.error("Failed to export statement for account {}", accountId, e);
            throw new RuntimeException("Statement export failed: " + e.getMessage(), e);
        }
    }
}

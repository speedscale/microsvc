package com.banking.transactionsservice.service;

import com.banking.transactionsservice.client.AccountsServiceClient;
import com.banking.transactionsservice.client.FraudServiceClient;
import com.banking.transactionsservice.dto.*;
import com.banking.transactionsservice.entity.Transaction;
import com.banking.transactionsservice.event.TransactionEventProducer;
import com.banking.transactionsservice.repository.TransactionRepository;
import io.opentelemetry.api.metrics.DoubleHistogram;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.locks.ReentrantLock;
import java.util.stream.Collectors;

@Service
@Transactional
public class TransactionService {
    
    private static final Logger logger = LoggerFactory.getLogger(TransactionService.class);

    // ISO 18245 merchant category codes used to tag outbound txns for the
    // fraud engine. Distribution mirrors the live merchant mix observed in
    // prod billing data: grocery is the long tail, dining/pharma/electronics
    // are episodic, gambling is rare. Withdrawals/deposits at the bank's own
    // ATM/branch are tagged 6011 (financial institutions).
    private static final String[] MCC_POOL = {
            "5411", "5411", "5411", "5411",   // grocery stores
            "5812", "5812", "5812",            // restaurants
            "5912", "5912",                    // drug stores
            "5732",                            // consumer electronics
            "7995",                            // gambling
            "5999", "5999", "5999",            // misc retail
            "5541",                            // service stations
    };

    private static String pickMerchantCategory(String transactionType) {
        if ("DEPOSIT".equals(transactionType) || "WITHDRAWAL".equals(transactionType)) {
            return "6011"; // financial institutions
        }
        return MCC_POOL[ThreadLocalRandom.current().nextInt(MCC_POOL.length)];
    }
    
    @Autowired
    private TransactionRepository transactionRepository;
    
    @Autowired
    private AccountsServiceClient accountsServiceClient;

    @Autowired
    private FraudServiceClient fraudServiceClient;

    @Autowired
    private TransactionEventProducer transactionEventProducer;

    @Autowired
    private PaymentComplianceService paymentComplianceService;

    @Autowired
    private DoubleHistogram depositAmountHistogram;

    @Autowired
    private DoubleHistogram withdrawAmountHistogram;

    @Autowired
    private DoubleHistogram transferAmountHistogram;

    // Demo fixture flag (default OFF). When enabled, deposit() normalizes the
    // memo for the ledger feed and trips on a null description. Used to stage a
    // reproducible bug for the Replay Lab demo. Never enable in production.
    @Value("${demo.memo-bug.enabled:false}")
    private boolean memoBugEnabled;

    private final ConcurrentMap<Long, ReentrantLock> accountLocks = new ConcurrentHashMap<>();
    
    public List<TransactionResponse> getUserTransactions(Long userId) {
        logger.info("Fetching transactions for user: {}", userId);
        List<Transaction> transactions = transactionRepository.findByUserIdOrderByCreatedAtDesc(userId);
        return transactions.stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }
    
    public List<TransactionResponse> getUserTransactionsByAccount(Long userId, Long accountId) {
        logger.info("Fetching transactions for user: {} and account: {}", userId, accountId);
        List<Transaction> transactions = transactionRepository.findByUserIdAndAccountIdOrderByCreatedAtDesc(userId, accountId);
        return transactions.stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }
    
    public TransactionResponse deposit(DepositRequest request, Long userId, HttpServletRequest httpRequest) {
        logger.info("Processing deposit for user: {}, account: {}, amount: {}",
                   userId, request.getAccountId(), request.getAmount());

        if (memoBugEnabled) {
            // Normalize the transaction memo for the downstream ledger feed.
            String memo = request.getDescription().trim().toUpperCase();
            logger.debug("Normalized ledger memo ({} chars) for account {}", memo.length(), request.getAccountId());
        }

        // Fraud check before processing
        var fraudResult = fraudServiceClient.checkTransaction(
                String.valueOf(request.getAccountId()), String.valueOf(userId),
                request.getAmount(), "DEPOSIT", pickMerchantCategory("DEPOSIT"));
        if (!fraudResult.getApproved()) {
            throw new RuntimeException("Transaction rejected by fraud check: " + fraudResult.getReason());
        }

        // Validate account ownership
        if (!accountsServiceClient.validateAccountOwnership(request.getAccountId(), httpRequest)) {
            throw new RuntimeException("Account not found or access denied");
        }
        
        Transaction savedTransaction = withAccountLock(request.getAccountId(), () -> {
            // Get current balance
            Double currentBalance = accountsServiceClient.getAccountBalance(request.getAccountId(), httpRequest);
            if (currentBalance == null) {
                throw new RuntimeException("Unable to retrieve account balance");
            }

            // Create transaction record
            Transaction transaction = new Transaction(
                userId,
                null,
                request.getAccountId(),
                request.getAmount(),
                Transaction.TransactionType.DEPOSIT,
                request.getDescription()
            );

            try {
                // Calculate new balance
                Double newBalance = currentBalance + request.getAmount();

                // Update account balance
                if (!accountsServiceClient.updateAccountBalance(request.getAccountId(), newBalance, httpRequest)) {
                    throw new RuntimeException("Failed to update account balance");
                }

                // Mark transaction as completed
                transaction.setStatus(Transaction.TransactionStatus.COMPLETED);
                transaction.setProcessedAt(LocalDateTime.now());

                Transaction completedTransaction = transactionRepository.save(transaction);
                logger.info("Deposit completed successfully for transaction: {}", completedTransaction.getId());
                return completedTransaction;
            } catch (Exception e) {
                // Mark transaction as failed
                transaction.setStatus(Transaction.TransactionStatus.FAILED);
                transaction.setProcessedAt(LocalDateTime.now());
                transactionRepository.save(transaction);

                logger.error("Deposit failed for user: {}, account: {}", userId, request.getAccountId(), e);
                throw new RuntimeException("Deposit transaction failed: " + e.getMessage());
            }
        });

        depositAmountHistogram.record(request.getAmount().doubleValue());
        transactionEventProducer.publishTransactionEvent(savedTransaction);
        paymentComplianceService.fanOutPaymentAndCompliance(
                savedTransaction.getId(), "DEPOSIT", request.getAmount());

        return convertToResponse(savedTransaction);
    }
    
    public TransactionResponse withdraw(WithdrawRequest request, Long userId, HttpServletRequest httpRequest) {
        logger.info("Processing withdrawal for user: {}, account: {}, amount: {}",
                   userId, request.getAccountId(), request.getAmount());

        // Fraud check before processing
        var fraudResult = fraudServiceClient.checkTransaction(
                String.valueOf(request.getAccountId()), String.valueOf(userId),
                request.getAmount(), "WITHDRAWAL", pickMerchantCategory("WITHDRAWAL"));
        if (!fraudResult.getApproved()) {
            throw new RuntimeException("Transaction rejected by fraud check: " + fraudResult.getReason());
        }

        // Validate account ownership
        if (!accountsServiceClient.validateAccountOwnership(request.getAccountId(), httpRequest)) {
            throw new RuntimeException("Account not found or access denied");
        }
        
        Transaction savedTransaction = withAccountLock(request.getAccountId(), () -> {
            // Get current balance
            Double currentBalance = accountsServiceClient.getAccountBalance(request.getAccountId(), httpRequest);
            if (currentBalance == null) {
                throw new RuntimeException("Unable to retrieve account balance");
            }

            // Check sufficient balance
            if (currentBalance < request.getAmount()) {
                throw new RuntimeException("Insufficient balance for withdrawal");
            }

            // Create transaction record
            Transaction transaction = new Transaction(
                userId,
                request.getAccountId(),
                null,
                request.getAmount(),
                Transaction.TransactionType.WITHDRAWAL,
                request.getDescription()
            );

            try {
                // Calculate new balance
                Double newBalance = currentBalance - request.getAmount();

                // Update account balance
                if (!accountsServiceClient.updateAccountBalance(request.getAccountId(), newBalance, httpRequest)) {
                    throw new RuntimeException("Failed to update account balance");
                }

                // Mark transaction as completed
                transaction.setStatus(Transaction.TransactionStatus.COMPLETED);
                transaction.setProcessedAt(LocalDateTime.now());

                Transaction completedTransaction = transactionRepository.save(transaction);
                logger.info("Withdrawal completed successfully for transaction: {}", completedTransaction.getId());
                return completedTransaction;
            } catch (Exception e) {
                // Mark transaction as failed
                transaction.setStatus(Transaction.TransactionStatus.FAILED);
                transaction.setProcessedAt(LocalDateTime.now());
                transactionRepository.save(transaction);

                logger.error("Withdrawal failed for user: {}, account: {}", userId, request.getAccountId(), e);
                throw new RuntimeException("Withdrawal transaction failed: " + e.getMessage());
            }
        });

        withdrawAmountHistogram.record(request.getAmount().doubleValue());
        transactionEventProducer.publishTransactionEvent(savedTransaction);
        paymentComplianceService.fanOutPaymentAndCompliance(
                savedTransaction.getId(), "WITHDRAWAL", request.getAmount());

        return convertToResponse(savedTransaction);
    }
    
    public TransactionResponse transfer(TransferRequest request, Long userId, HttpServletRequest httpRequest) {
        logger.info("Processing transfer for user: {}, from: {}, to: {}, amount: {}",
                   userId, request.getFromAccountId(), request.getToAccountId(), request.getAmount());

        // Fraud check before processing
        var fraudResult = fraudServiceClient.checkTransaction(
                String.valueOf(request.getFromAccountId()), String.valueOf(userId),
                request.getAmount(), "TRANSFER", pickMerchantCategory("TRANSFER"));
        if (!fraudResult.getApproved()) {
            throw new RuntimeException("Transaction rejected by fraud check: " + fraudResult.getReason());
        }

        // Validate from account ownership
        if (!accountsServiceClient.validateAccountOwnership(request.getFromAccountId(), httpRequest)) {
            throw new RuntimeException("From account not found or access denied");
        }
        
        paymentComplianceService.verifyTransferCompliance(
                request.getFromAccountId(), request.getToAccountId());
        
        Transaction savedTransaction = withAccountLocks(request.getFromAccountId(), request.getToAccountId(), () -> {
            // Get current balance of from account
            Double fromBalance = accountsServiceClient.getAccountBalance(request.getFromAccountId(), httpRequest);
            if (fromBalance == null) {
                throw new RuntimeException("Unable to retrieve from account balance");
            }

            // Check sufficient balance
            if (fromBalance < request.getAmount()) {
                throw new RuntimeException("Insufficient balance for transfer");
            }

            // Get current balance of to account (validate it exists)
            Double toBalance = accountsServiceClient.getAccountBalance(request.getToAccountId(), httpRequest);
            if (toBalance == null) {
                throw new RuntimeException("To account not found or inaccessible");
            }

            // Create transaction record
            Transaction transaction = new Transaction(
                userId,
                request.getFromAccountId(),
                request.getToAccountId(),
                request.getAmount(),
                Transaction.TransactionType.TRANSFER,
                request.getDescription()
            );

            try {
                // Calculate new balances
                Double newFromBalance = fromBalance - request.getAmount();
                Double newToBalance = toBalance + request.getAmount();

                // Update from account balance
                if (!accountsServiceClient.updateAccountBalance(request.getFromAccountId(), newFromBalance, httpRequest)) {
                    throw new RuntimeException("Failed to update from account balance");
                }

                // Update to account balance
                if (!accountsServiceClient.updateAccountBalance(request.getToAccountId(), newToBalance, httpRequest)) {
                    // Rollback from account balance
                    accountsServiceClient.updateAccountBalance(request.getFromAccountId(), fromBalance, httpRequest);
                    throw new RuntimeException("Failed to update to account balance");
                }

                // Mark transaction as completed
                transaction.setStatus(Transaction.TransactionStatus.COMPLETED);
                transaction.setProcessedAt(LocalDateTime.now());

                Transaction completedTransaction = transactionRepository.save(transaction);
                logger.info("Transfer completed successfully for transaction: {}", completedTransaction.getId());
                return completedTransaction;
            } catch (Exception e) {
                // Mark transaction as failed
                transaction.setStatus(Transaction.TransactionStatus.FAILED);
                transaction.setProcessedAt(LocalDateTime.now());
                transactionRepository.save(transaction);

                logger.error("Transfer failed for user: {}, from: {}, to: {}",
                            userId, request.getFromAccountId(), request.getToAccountId(), e);
                throw new RuntimeException("Transfer transaction failed: " + e.getMessage());
            }
        });

        transferAmountHistogram.record(request.getAmount().doubleValue());
        transactionEventProducer.publishTransactionEvent(savedTransaction);
        paymentComplianceService.fanOutPaymentAndCompliance(
                savedTransaction.getId(), "TRANSFER", request.getAmount());

        return convertToResponse(savedTransaction);
    }
    
    public TransactionResponse createTransaction(CreateTransactionRequest request, Long userId, HttpServletRequest httpRequest) {
        logger.info("Creating transaction for user: {}, account: {}, type: {}, amount: {}", 
                   userId, request.getAccountId(), request.getType(), request.getAmount());
        
        switch (request.getType()) {
            case "DEPOSIT":
                DepositRequest depositRequest = new DepositRequest();
                depositRequest.setAccountId(request.getAccountId());
                depositRequest.setAmount(request.getAmount());
                depositRequest.setDescription(request.getDescription());
                return deposit(depositRequest, userId, httpRequest);
                
            case "WITHDRAWAL":
                WithdrawRequest withdrawRequest = new WithdrawRequest();
                withdrawRequest.setAccountId(request.getAccountId());
                withdrawRequest.setAmount(request.getAmount());
                withdrawRequest.setDescription(request.getDescription());
                return withdraw(withdrawRequest, userId, httpRequest);
                
            case "TRANSFER":
                if (request.getToAccountId() == null) {
                    throw new RuntimeException("To account ID is required for transfer transactions");
                }
                TransferRequest transferRequest = new TransferRequest();
                transferRequest.setFromAccountId(request.getAccountId());
                transferRequest.setToAccountId(request.getToAccountId());
                transferRequest.setAmount(request.getAmount());
                transferRequest.setDescription(request.getDescription());
                return transfer(transferRequest, userId, httpRequest);
                
            default:
                throw new RuntimeException("Invalid transaction type: " + request.getType());
        }
    }

    private <T> T withAccountLock(Long accountId, LockedOperation<T> operation) {
        ReentrantLock lock = getAccountLock(accountId);
        lock.lock();
        try {
            return operation.execute();
        } finally {
            lock.unlock();
        }
    }

    private <T> T withAccountLocks(Long firstAccountId, Long secondAccountId, LockedOperation<T> operation) {
        Objects.requireNonNull(firstAccountId, "firstAccountId must not be null");
        Objects.requireNonNull(secondAccountId, "secondAccountId must not be null");

        if (Objects.equals(firstAccountId, secondAccountId)) {
            return withAccountLock(firstAccountId, operation);
        }

        Long lowerAccountId = Long.compare(firstAccountId, secondAccountId) < 0 ? firstAccountId : secondAccountId;
        Long higherAccountId = Long.compare(firstAccountId, secondAccountId) < 0 ? secondAccountId : firstAccountId;
        ReentrantLock firstLock = getAccountLock(lowerAccountId);
        ReentrantLock secondLock = getAccountLock(higherAccountId);

        firstLock.lock();
        try {
            secondLock.lock();
            try {
                return operation.execute();
            } finally {
                secondLock.unlock();
            }
        } finally {
            firstLock.unlock();
        }
    }

    private ReentrantLock getAccountLock(Long accountId) {
        Objects.requireNonNull(accountId, "accountId must not be null");
        return accountLocks.computeIfAbsent(accountId, ignored -> new ReentrantLock());
    }

    @FunctionalInterface
    private interface LockedOperation<T> {
        T execute();
    }
    
    private TransactionResponse convertToResponse(Transaction transaction) {
        return new TransactionResponse(
            transaction.getId(),
            transaction.getUserId(),
            transaction.getFromAccountId(),
            transaction.getToAccountId(),
            transaction.getAmount(),
            transaction.getType(),
            transaction.getDescription(),
            transaction.getStatus(),
            transaction.getCreatedAt(),
            transaction.getProcessedAt()
        );
    }
}

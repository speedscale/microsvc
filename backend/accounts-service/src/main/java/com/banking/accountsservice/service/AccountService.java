package com.banking.accountsservice.service;

import com.banking.accountsservice.dto.AccountCreateRequest;
import com.banking.accountsservice.dto.AccountResponse;
import com.banking.accountsservice.dto.BalanceResponse;
import com.banking.accountsservice.entity.Account;
import com.banking.accountsservice.repository.AccountRepository;
import io.opentelemetry.api.metrics.LongCounter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class AccountService {
    
    private static final Logger logger = LoggerFactory.getLogger(AccountService.class);
    
    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private LongCounter createdAccountsCounter;
    
    private final SecureRandom random = new SecureRandom();
    
    public List<AccountResponse> getUserAccounts(Long userId) {
        logger.info("Fetching accounts for user: {}", userId);
        List<Account> accounts = accountRepository.findByUserId(userId);
        return accounts.stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }
    
    public AccountResponse getAccountById(Long accountId, Long userId) {
        logger.info("Fetching account {} for user: {}", accountId, userId);
        Account account = accountRepository.findByIdAndUserId(accountId, userId)
                .orElseThrow(() -> new RuntimeException("Account not found or access denied"));
        return convertToResponse(account);
    }
    
    public BalanceResponse getAccountBalance(Long accountId, Long userId) {
        logger.info("Fetching balance for account {} for user: {}", accountId, userId);
        Account account = accountRepository.findByIdAndUserId(accountId, userId)
                .orElseThrow(() -> new RuntimeException("Account not found or access denied"));
        return new BalanceResponse(account.getId(), account.getAccountNumber(), account.getBalance());
    }
    
    public AccountResponse createAccount(AccountCreateRequest request, Long userId) {
        logger.info("Creating new {} account for user: {} with initial balance: {}", 
                   request.getAccountType(), userId, request.getInitialBalance());
        
        String accountNumber = generateAccountNumber();
        
        Account account = new Account();
        account.setUserId(userId);
        account.setAccountNumber(accountNumber);
        account.setBalance(request.getInitialBalance() != null ? request.getInitialBalance() : BigDecimal.ZERO);
        account.setAccountType(request.getAccountType());
        
        Account savedAccount = accountRepository.save(account);
        logger.info("Created account {} for user: {} with balance: {}", 
                   savedAccount.getAccountNumber(), userId, savedAccount.getBalance());
        
        createdAccountsCounter.add(1);
        
        return convertToResponse(savedAccount);
    }
    
    private String generateAccountNumber() {
        String accountNumber;
        do {
            // Generate 12-digit account number
            long number = 100000000000L + (long) (random.nextDouble() * 900000000000L);
            accountNumber = String.valueOf(number);
        } while (accountRepository.existsByAccountNumber(accountNumber));
        
        return accountNumber;
    }
    
    public boolean validateAccountOwnership(Long accountId, Long userId) {
        logger.info("Validating ownership of account {} for user: {}", accountId, userId);
        return accountRepository.existsByIdAndUserId(accountId, userId);
    }
    
    public boolean updateBalance(Long accountId, BigDecimal newBalance, Long userId) {
        logger.info("Updating balance for account {} to {} for user: {}", accountId, newBalance, userId);
        Account account = accountRepository.findByIdAndUserId(accountId, userId)
                .orElseThrow(() -> new RuntimeException("Account not found or access denied"));
        account.setBalance(newBalance);
        accountRepository.save(account);
        return true;
    }

    private AccountResponse convertToResponse(Account account) {
        return new AccountResponse(
                account.getId(),
                account.getUserId(),
                account.getAccountNumber(),
                account.getBalance(),
                account.getAccountType(),
                account.getCreatedAt(),
                account.getUpdatedAt()
        );
    }
}
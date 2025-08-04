package com.banking.transactionsservice.service;

import com.banking.transactionsservice.client.AccountsServiceClient;
import com.banking.transactionsservice.dto.*;
import com.banking.transactionsservice.entity.Transaction;
import com.banking.transactionsservice.repository.TransactionRepository;
import io.opentelemetry.api.metrics.DoubleHistogram;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TransactionServiceTest {

    @Mock
    private TransactionRepository transactionRepository;

    @Mock
    private AccountsServiceClient accountsServiceClient;

    @Mock
    private DoubleHistogram depositAmountHistogram;

    @Mock
    private DoubleHistogram withdrawAmountHistogram;

    @Mock
    private DoubleHistogram transferAmountHistogram;

    @InjectMocks
    private TransactionService transactionService;

    @Mock
    private HttpServletRequest httpServletRequest;

    private Transaction testTransaction;
    private Long testUserId = 1L;
    private Long testAccountId = 1L;

    @BeforeEach
    void setUp() {
        testTransaction = new Transaction();
        testTransaction.setId(1L);
        testTransaction.setUserId(testUserId);
        testTransaction.setToAccountId(testAccountId);
        testTransaction.setAmount(BigDecimal.valueOf(100.00));
        testTransaction.setType(Transaction.TransactionType.DEPOSIT);
        testTransaction.setDescription("Test deposit");
        testTransaction.setStatus(Transaction.TransactionStatus.COMPLETED);
        testTransaction.setCreatedAt(LocalDateTime.now());
        testTransaction.setProcessedAt(LocalDateTime.now());
    }

    @Test
    void testGetUserTransactions() {
        // Arrange
        List<Transaction> transactions = Arrays.asList(testTransaction);
        when(transactionRepository.findByUserIdOrderByCreatedAtDesc(testUserId)).thenReturn(transactions);

        // Act
        List<TransactionResponse> result = transactionService.getUserTransactions(testUserId);

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals(testTransaction.getId(), result.get(0).getId());
        assertEquals(testTransaction.getAmount(), result.get(0).getAmount());
        assertEquals(testTransaction.getType(), result.get(0).getType());
        
        verify(transactionRepository, times(1)).findByUserIdOrderByCreatedAtDesc(testUserId);
    }

    @Test
    void testDepositSuccess() {
        // Arrange
        DepositRequest request = new DepositRequest(testAccountId, BigDecimal.valueOf(100.00), "Test deposit");
        when(accountsServiceClient.validateAccountOwnership(testAccountId, httpServletRequest)).thenReturn(true);
        when(accountsServiceClient.getAccountBalance(testAccountId, httpServletRequest)).thenReturn(BigDecimal.valueOf(500.00));
        when(accountsServiceClient.updateAccountBalance(eq(testAccountId), eq(BigDecimal.valueOf(600.00)), eq(httpServletRequest))).thenReturn(true);
        when(transactionRepository.save(any(Transaction.class))).thenReturn(testTransaction);

        // Act
        TransactionResponse result = transactionService.deposit(request, testUserId, httpServletRequest);

        // Assert
        assertNotNull(result);
        assertEquals(testTransaction.getId(), result.getId());
        assertEquals(testTransaction.getAmount(), result.getAmount());
        assertEquals(Transaction.TransactionType.DEPOSIT, result.getType());
        
        verify(accountsServiceClient, times(1)).validateAccountOwnership(testAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).getAccountBalance(testAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).updateAccountBalance(testAccountId, BigDecimal.valueOf(600.00), httpServletRequest);
        verify(transactionRepository, times(1)).save(any(Transaction.class));
    }

    @Test
    void testDepositAccountNotOwned() {
        // Arrange
        DepositRequest request = new DepositRequest(testAccountId, BigDecimal.valueOf(100.00), "Test deposit");
        when(accountsServiceClient.validateAccountOwnership(testAccountId, httpServletRequest)).thenReturn(false);

        // Act & Assert
        assertThrows(RuntimeException.class, () -> {
            transactionService.deposit(request, testUserId, httpServletRequest);
        });
        
        verify(accountsServiceClient, times(1)).validateAccountOwnership(testAccountId, httpServletRequest);
        verify(accountsServiceClient, never()).getAccountBalance(anyLong(), any(HttpServletRequest.class));
        verify(transactionRepository, never()).save(any(Transaction.class));
    }

    @Test
    void testWithdrawSuccess() {
        // Arrange
        WithdrawRequest request = new WithdrawRequest(testAccountId, BigDecimal.valueOf(100.00), "Test withdrawal");
        when(accountsServiceClient.validateAccountOwnership(testAccountId, httpServletRequest)).thenReturn(true);
        when(accountsServiceClient.getAccountBalance(testAccountId, httpServletRequest)).thenReturn(BigDecimal.valueOf(500.00));
        when(accountsServiceClient.updateAccountBalance(eq(testAccountId), eq(BigDecimal.valueOf(400.00)), eq(httpServletRequest))).thenReturn(true);
        
        Transaction withdrawalTransaction = new Transaction();
        withdrawalTransaction.setId(2L);
        withdrawalTransaction.setUserId(testUserId);
        withdrawalTransaction.setFromAccountId(testAccountId);
        withdrawalTransaction.setAmount(BigDecimal.valueOf(100.00));
        withdrawalTransaction.setType(Transaction.TransactionType.WITHDRAWAL);
        withdrawalTransaction.setStatus(Transaction.TransactionStatus.COMPLETED);
        withdrawalTransaction.setCreatedAt(LocalDateTime.now());
        withdrawalTransaction.setProcessedAt(LocalDateTime.now());
        
        when(transactionRepository.save(any(Transaction.class))).thenReturn(withdrawalTransaction);

        // Act
        TransactionResponse result = transactionService.withdraw(request, testUserId, httpServletRequest);

        // Assert
        assertNotNull(result);
        assertEquals(withdrawalTransaction.getId(), result.getId());
        assertEquals(withdrawalTransaction.getAmount(), result.getAmount());
        assertEquals(Transaction.TransactionType.WITHDRAWAL, result.getType());
        
        verify(accountsServiceClient, times(1)).validateAccountOwnership(testAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).getAccountBalance(testAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).updateAccountBalance(testAccountId, BigDecimal.valueOf(400.00), httpServletRequest);
        verify(transactionRepository, times(1)).save(any(Transaction.class));
    }

    @Test
    void testWithdrawInsufficientBalance() {
        // Arrange
        WithdrawRequest request = new WithdrawRequest(testAccountId, BigDecimal.valueOf(600.00), "Test withdrawal");
        when(accountsServiceClient.validateAccountOwnership(testAccountId, httpServletRequest)).thenReturn(true);
        when(accountsServiceClient.getAccountBalance(testAccountId, httpServletRequest)).thenReturn(BigDecimal.valueOf(500.00));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> {
            transactionService.withdraw(request, testUserId, httpServletRequest);
        });
        
        verify(accountsServiceClient, times(1)).validateAccountOwnership(testAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).getAccountBalance(testAccountId, httpServletRequest);
        verify(accountsServiceClient, never()).updateAccountBalance(anyLong(), any(BigDecimal.class), any(HttpServletRequest.class));
    }

    @Test
    void testTransferSuccess() {
        // Arrange
        Long fromAccountId = 1L;
        Long toAccountId = 2L;
        TransferRequest request = new TransferRequest(fromAccountId, toAccountId, BigDecimal.valueOf(100.00), "Test transfer");
        
        when(accountsServiceClient.validateAccountOwnership(fromAccountId, httpServletRequest)).thenReturn(true);
        when(accountsServiceClient.getAccountBalance(fromAccountId, httpServletRequest)).thenReturn(BigDecimal.valueOf(500.00));
        when(accountsServiceClient.getAccountBalance(toAccountId, httpServletRequest)).thenReturn(BigDecimal.valueOf(200.00));
        when(accountsServiceClient.updateAccountBalance(eq(fromAccountId), eq(BigDecimal.valueOf(400.00)), eq(httpServletRequest))).thenReturn(true);
        when(accountsServiceClient.updateAccountBalance(eq(toAccountId), eq(BigDecimal.valueOf(300.00)), eq(httpServletRequest))).thenReturn(true);
        
        Transaction transferTransaction = new Transaction();
        transferTransaction.setId(3L);
        transferTransaction.setUserId(testUserId);
        transferTransaction.setFromAccountId(fromAccountId);
        transferTransaction.setToAccountId(toAccountId);
        transferTransaction.setAmount(BigDecimal.valueOf(100.00));
        transferTransaction.setType(Transaction.TransactionType.TRANSFER);
        transferTransaction.setStatus(Transaction.TransactionStatus.COMPLETED);
        transferTransaction.setCreatedAt(LocalDateTime.now());
        transferTransaction.setProcessedAt(LocalDateTime.now());
        
        when(transactionRepository.save(any(Transaction.class))).thenReturn(transferTransaction);

        // Act
        TransactionResponse result = transactionService.transfer(request, testUserId, httpServletRequest);

        // Assert
        assertNotNull(result);
        assertEquals(transferTransaction.getId(), result.getId());
        assertEquals(transferTransaction.getAmount(), result.getAmount());
        assertEquals(Transaction.TransactionType.TRANSFER, result.getType());
        
        verify(accountsServiceClient, times(1)).validateAccountOwnership(fromAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).getAccountBalance(fromAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).getAccountBalance(toAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).updateAccountBalance(fromAccountId, BigDecimal.valueOf(400.00), httpServletRequest);
        verify(accountsServiceClient, times(1)).updateAccountBalance(toAccountId, BigDecimal.valueOf(300.00), httpServletRequest);
        verify(transactionRepository, times(1)).save(any(Transaction.class));
    }

    @Test
    void testTransferInsufficientBalance() {
        // Arrange
        Long fromAccountId = 1L;
        Long toAccountId = 2L;
        TransferRequest request = new TransferRequest(fromAccountId, toAccountId, BigDecimal.valueOf(600.00), "Test transfer");
        
        when(accountsServiceClient.validateAccountOwnership(fromAccountId, httpServletRequest)).thenReturn(true);
        when(accountsServiceClient.getAccountBalance(fromAccountId, httpServletRequest)).thenReturn(BigDecimal.valueOf(500.00));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> {
            transactionService.transfer(request, testUserId, httpServletRequest);
        });
        
        verify(accountsServiceClient, times(1)).validateAccountOwnership(fromAccountId, httpServletRequest);
        verify(accountsServiceClient, times(1)).getAccountBalance(fromAccountId, httpServletRequest);
        verify(accountsServiceClient, never()).updateAccountBalance(anyLong(), any(BigDecimal.class), any(HttpServletRequest.class));
    }
}

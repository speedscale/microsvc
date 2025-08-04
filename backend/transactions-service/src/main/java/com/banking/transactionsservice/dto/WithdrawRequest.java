package com.banking.transactionsservice.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;


public class WithdrawRequest {
    
    @NotNull(message = "Account ID is required")
    private Long accountId;
    
    @NotNull(message = "Amount is required")
    @Positive(message = "Amount must be positive")
    private Double amount;
    
    private String description;
    
    public WithdrawRequest() {}
    
    public WithdrawRequest(Long accountId, Double amount, String description) {
        this.accountId = accountId;
        this.amount = amount;
        this.description = description;
    }
    
    public Long getAccountId() {
        return accountId;
    }
    
    public void setAccountId(Long accountId) {
        this.accountId = accountId;
    }
    
    public Double getAmount() {
        return amount;
    }
    
    public void setAmount(Double amount) {
        this.amount = amount;
    }
    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }
}
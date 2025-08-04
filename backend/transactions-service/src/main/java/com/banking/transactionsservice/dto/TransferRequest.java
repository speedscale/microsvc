package com.banking.transactionsservice.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;


public class TransferRequest {
    
    @NotNull(message = "From Account ID is required")
    private Long fromAccountId;
    
    @NotNull(message = "To Account ID is required")
    private Long toAccountId;
    
    @NotNull(message = "Amount is required")
    @Positive(message = "Amount must be positive")
    private Double amount;
    
    private String description;
    
    public TransferRequest() {}
    
    public TransferRequest(Long fromAccountId, Long toAccountId, Double amount, String description) {
        this.fromAccountId = fromAccountId;
        this.toAccountId = toAccountId;
        this.amount = amount;
        this.description = description;
    }
    
    public Long getFromAccountId() {
        return fromAccountId;
    }
    
    public void setFromAccountId(Long fromAccountId) {
        this.fromAccountId = fromAccountId;
    }
    
    public Long getToAccountId() {
        return toAccountId;
    }
    
    public void setToAccountId(Long toAccountId) {
        this.toAccountId = toAccountId;
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
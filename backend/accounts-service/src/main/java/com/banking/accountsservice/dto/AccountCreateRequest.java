package com.banking.accountsservice.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.DecimalMin;
import java.math.BigDecimal;

public class AccountCreateRequest {
    
    @NotBlank(message = "Account type is required")
    @Pattern(regexp = "^(CHECKING|SAVINGS|CREDIT)$", message = "Account type must be CHECKING, SAVINGS, or CREDIT")
    private String accountType;
    
    @DecimalMin(value = "0.0", message = "Initial balance cannot be negative")
    private BigDecimal initialBalance = BigDecimal.ZERO;
    
    public AccountCreateRequest() {}
    
    public AccountCreateRequest(String accountType) {
        this.accountType = accountType;
    }
    
    public AccountCreateRequest(String accountType, BigDecimal initialBalance) {
        this.accountType = accountType;
        this.initialBalance = initialBalance;
    }
    
    public String getAccountType() {
        return accountType;
    }
    
    public void setAccountType(String accountType) {
        this.accountType = accountType;
    }
    
    public BigDecimal getInitialBalance() {
        return initialBalance;
    }
    
    public void setInitialBalance(BigDecimal initialBalance) {
        this.initialBalance = initialBalance;
    }
}
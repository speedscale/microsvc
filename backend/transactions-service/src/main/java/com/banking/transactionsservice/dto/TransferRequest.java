package com.banking.transactionsservice.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.math.BigDecimal;

@ValidTransfer
public class TransferRequest {
    
    @NotNull(message = "From Account ID is required")
    private Long fromAccountId;
    
    @NotNull(message = "To Account ID is required")
    private Long toAccountId;
    
    @NotNull(message = "Amount is required")
    @Positive(message = "Amount must be positive")
    private BigDecimal amount;
    
    private String description;
    
    public TransferRequest() {}
    
    public TransferRequest(Long fromAccountId, Long toAccountId, BigDecimal amount, String description) {
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
    
    public BigDecimal getAmount() {
        return amount;
    }
    
    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }
    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }
}

@Constraint(validatedBy = TransferValidator.class)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@interface ValidTransfer {
    String message() default "Cannot transfer to the same account";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

class TransferValidator implements ConstraintValidator<ValidTransfer, TransferRequest> {
    @Override
    public boolean isValid(TransferRequest request, ConstraintValidatorContext context) {
        if (request.getFromAccountId() == null || request.getToAccountId() == null) {
            return true; // Let @NotNull handle null values
        }
        return !request.getFromAccountId().equals(request.getToAccountId());
    }
}
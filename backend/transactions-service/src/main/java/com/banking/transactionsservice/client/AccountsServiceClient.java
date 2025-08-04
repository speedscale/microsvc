package com.banking.transactionsservice.client;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

@Component
public class AccountsServiceClient {
    
    private static final Logger logger = LoggerFactory.getLogger(AccountsServiceClient.class);
    
    @Value("${accounts.service.url:http://localhost:8082}")
    private String accountsServiceUrl;
    
    private final RestTemplate restTemplate;
    
    public AccountsServiceClient() {
        this.restTemplate = new RestTemplate();
    }
    
    public boolean validateAccountOwnership(Long accountId, HttpServletRequest request) {
        try {
            String url = accountsServiceUrl + "/" + accountId;
            
            HttpHeaders headers = new HttpHeaders();
            String authHeader = request.getHeader("Authorization");
            logger.info("Authorization header: {}", authHeader);
            headers.set("Authorization", authHeader);
            HttpEntity<String> entity = new HttpEntity<>(headers);
            
            ResponseEntity<Map> response = restTemplate.exchange(
                url, HttpMethod.GET, entity, Map.class);
            
            return response.getStatusCode() == HttpStatus.OK;
        } catch (RestClientException e) {
            logger.error("Error validating account ownership for account {}: {}", 
                        accountId, e.getMessage());
            return false;
        }
    }
    
    public Double getAccountBalance(Long accountId, HttpServletRequest request) {
        try {
            String url = accountsServiceUrl + "/" + accountId + "/balance";
            
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", request.getHeader("Authorization"));
            HttpEntity<String> entity = new HttpEntity<>(headers);
            
            ResponseEntity<Map> response = restTemplate.exchange(
                url, HttpMethod.GET, entity, Map.class);
            
            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                Object balanceObj = response.getBody().get("balance");
                if (balanceObj instanceof Number) {
                    return ((Number) balanceObj).doubleValue();
                }
            }
            return null;
        } catch (RestClientException e) {
            logger.error("Error getting account balance for account {}: {}", accountId, e.getMessage());
            return null;
        }
    }
    
    public boolean updateAccountBalance(Long accountId, Double newBalance, HttpServletRequest request) {
        try {
            String url = accountsServiceUrl + "/" + accountId + "/balance";
            
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", request.getHeader("Authorization"));
            headers.setContentType(MediaType.APPLICATION_JSON);
            
            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("balance", newBalance);
            
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
            
            ResponseEntity<Void> response = restTemplate.exchange(
                url, HttpMethod.PUT, entity, Void.class);
            
            return response.getStatusCode() == HttpStatus.OK;
        } catch (RestClientException e) {
            logger.error("Error updating account balance for account {}: {}", accountId, e.getMessage());
            return false;
        }
    }
}

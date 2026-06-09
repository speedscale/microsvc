package com.banking.apigateway.filter;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.Random;

@Component
public class FaultInjectionFilter implements GlobalFilter, Ordered {

    private final double faultRate;
    private final Random random = new Random();

    private static final HttpStatus[] FAULTS = {
        HttpStatus.INTERNAL_SERVER_ERROR,
        HttpStatus.INTERNAL_SERVER_ERROR,
        HttpStatus.SERVICE_UNAVAILABLE
    };

    public FaultInjectionFilter(
            @Value("${fault.injection.rate:0.008}") double faultRate) {
        this.faultRate = faultRate;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        if (random.nextDouble() < faultRate) {
            HttpStatus fault = FAULTS[random.nextInt(FAULTS.length)];
            exchange.getResponse().setStatusCode(fault);
            return exchange.getResponse().setComplete();
        }
        return chain.filter(exchange);
    }

    @Override
    public int getOrder() {
        return Ordered.LOWEST_PRECEDENCE - 1;
    }
}

package com.banking.transactionsservice.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.concurrent.ThreadLocalRandom;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
@ConditionalOnProperty(name = "error-spike.enabled", havingValue = "true", matchIfMissing = true)
public class ErrorSpikeFilter extends OncePerRequestFilter {

    @Value("${error-spike.probability:0.30}")
    private double probability;

    @Value("${error-spike.minute-marks:10,40}")
    private String minuteMarks;

    @Value("${error-spike.duration-minutes:2}")
    private int durationMinutes;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                     FilterChain chain) throws ServletException, IOException {
        if (isSpikeWindow() && ThreadLocalRandom.current().nextDouble() < probability) {
            response.sendError(HttpServletResponse.SC_SERVICE_UNAVAILABLE, "service temporarily degraded");
            return;
        }
        chain.doFilter(request, response);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/actuator");
    }

    private boolean isSpikeWindow() {
        int minute = LocalDateTime.now().getMinute();
        for (String mark : minuteMarks.split(",")) {
            int m = Integer.parseInt(mark.trim());
            if (minute >= m && minute < m + durationMinutes) {
                return true;
            }
        }
        return false;
    }
}

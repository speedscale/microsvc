package com.banking.demo;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {"demo.listener-enabled=false", "otel.sdk.disabled=true"})
@AutoConfigureMockMvc
class HttpTest {
    @Autowired MockMvc mvc;

    @Test void protectsLedgerAndReadiness() throws Exception {
        mvc.perform(get("/ledger")).andExpect(status().isUnauthorized());
        mvc.perform(get("/ledger").header("Authorization", "Bearer invalid")).andExpect(status().isUnauthorized());
        mvc.perform(get("/ready")).andExpect(status().isUnauthorized());
        mvc.perform(get("/ledger").with(jwt())).andExpect(status().isOk()).andExpect(jsonPath("$.entries").isEmpty());
        mvc.perform(get("/ready").with(jwt())).andExpect(status().isOk()).andExpect(jsonPath("$.assigned").value(false));
        mvc.perform(get("/actuator/health")).andExpect(status().isOk());
    }
}

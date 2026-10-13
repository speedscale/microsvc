package com.banking.demo;

import org.junit.jupiter.api.Test;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.boot.test.web.client.MockServerRestTemplateCustomizer;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

class PartnerApiTest {
    @Test void acceptsOnlyExplicitDecisions() {
        for (String decision : new String[] {"APPROVED", "REVIEW", "UNKNOWN"}) {
            var mock = new MockServerRestTemplateCustomizer();
            var api = new PartnerApi(new RestTemplateBuilder(mock), "http://partner.test");
            mock.getServer().expect(requestTo("http://partner.test/assessment/70668"))
                    .andExpect(method(HttpMethod.GET))
                    .andRespond(withSuccess("{\"decision\":\"" + decision + "\"}", MediaType.APPLICATION_JSON));
            if ("UNKNOWN".equals(decision)) {
                assertThatThrownBy(() -> api.assess(70668)).hasMessage("Invalid partner decision");
            } else {
                assertThat(api.assess(70668)).isEqualTo(decision);
            }
            mock.getServer().verify();
        }
    }

    @Test void refusesErrorsAndEmptyResponses() {
        var mock = new MockServerRestTemplateCustomizer();
        var api = new PartnerApi(new RestTemplateBuilder(mock), "http://partner.test");
        mock.getServer().expect(requestTo("http://partner.test/assessment/1")).andRespond(withServerError());
        assertThatThrownBy(() -> api.assess(1)).isInstanceOf(org.springframework.web.client.HttpServerErrorException.class);
        mock.getServer().verify();
        mock.getServer().reset();
        mock.getServer().expect(requestTo("http://partner.test/assessment/1"))
                .andRespond(withSuccess("", MediaType.APPLICATION_JSON));
        assertThatThrownBy(() -> api.assess(1)).hasMessage("Invalid partner decision");
    }
}

package com.qa.tests.base;

import com.qa.tests.clients.LoanClient;
import com.qa.tests.utils.TestConfig;
import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeAll;

public abstract class BaseApiTest {

    protected static LoanClient loanClient;

    @BeforeAll
    static void setUpApiTests() {
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
        loanClient = new LoanClient(TestConfig.getBaseUrl());
    }
}

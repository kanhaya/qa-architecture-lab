package com.qa.tests.tests.smoke;

import com.qa.tests.base.BaseApiTest;
import com.qa.tests.utils.TestDataFactory;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.notNullValue;

@Tag("smoke")
class SmokeTests extends BaseApiTest {

    @Test
    void healthCheck_returnsUp() {
        loanClient.getHealth()
                .then()
                .statusCode(200)
                .body("status", equalTo("UP"));
    }

    @Test
    void getLoans_returnsSeededData() {
        loanClient.getLoans()
                .then()
                .statusCode(200)
                .contentType("application/json")
                .body("size()", greaterThan(0))
                .body("[0].id", notNullValue())
                .body("[0].customerName", notNullValue())
                .body("[0].amount", notNullValue())
                .body("[0].status", notNullValue());
    }

    @Test
    void getLoanById_returnsLoan() {
        loanClient.getLoan(101)
                .then()
                .statusCode(200)
                .body("id", equalTo(101))
                .body("customerName", equalTo("Rahul"))
                .body("amount", equalTo(500000))
                .body("status", equalTo("APPROVED"));
    }

    @Test
    void createLoan_returnsPendingStatus() {
        loanClient.createLoan(TestDataFactory.validLoan())
                .then()
                .statusCode(201)
                .body("id", greaterThan(0))
                .body("customerName", equalTo("Test Customer"))
                .body("amount", equalTo(250000))
                .body("status", equalTo("PENDING"));
    }
}

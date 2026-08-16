package com.qa.tests.tests.negative;

import com.qa.tests.base.BaseApiTest;
import com.qa.tests.utils.TestDataFactory;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;

@Tag("negative")
class NegativeTests extends BaseApiTest {

    @Test
    void getLoanByInvalidId_returns404() {
        loanClient.getLoan(999999)
                .then()
                .statusCode(404)
                .body("status", equalTo(404))
                .body("error", equalTo("Not Found"))
                .body("message", containsString("999999"))
                .body("timestamp", notNullValue())
                .body("path", equalTo("/api/loans/999999"));
    }

    @Test
    void createLoan_missingCustomerName_returns400() {
        loanClient.createLoan(TestDataFactory.invalidLoanMissingName())
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("error", equalTo("Bad Request"))
                .body("message", notNullValue())
                .body("timestamp", notNullValue())
                .body("path", equalTo("/api/loans"));
    }

    @Test
    void createLoan_emptyCustomerName_returns400() {
        loanClient.createLoan(TestDataFactory.invalidLoanEmptyName())
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("message", notNullValue());
    }

    @Test
    void createLoan_shortCustomerName_returns400() {
        loanClient.createLoan(TestDataFactory.invalidLoanShortName())
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("message", containsString("2 and 100"));
    }

    @Test
    void createLoan_zeroAmount_returns400() {
        loanClient.createLoan(TestDataFactory.zeroAmountLoan())
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("message", containsString("greater than zero"));
    }

    @Test
    void createLoan_negativeAmount_returns400() {
        loanClient.createLoan(TestDataFactory.negativeAmountLoan())
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("message", containsString("greater than zero"));
    }

    @Test
    void createLoan_amountAboveMaximum_returns400() {
        loanClient.createLoan(TestDataFactory.largeAmountLoan())
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("message", containsString("10,000,000"));
    }

    @Test
    void updateLoanStatus_invalidStatus_returns400() {
        loanClient.updateLoanStatusRaw(101, "{\"status\":\"INVALID_STATUS\"}")
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("message", equalTo("Malformed JSON request"));
    }

    @Test
    void updateLoanStatus_nonExistentLoan_returns404() {
        loanClient.updateLoanStatus(999999, TestDataFactory.statusUpdate("APPROVED"))
                .then()
                .statusCode(404)
                .body("status", equalTo(404));
    }

    @Test
    void deleteNonExistentLoan_returns404() {
        loanClient.deleteLoan(999999)
                .then()
                .statusCode(404)
                .body("status", equalTo(404));
    }

    @Test
    void createLoan_malformedJson_returns400() {
        loanClient.createLoanRaw("{invalid json")
                .then()
                .statusCode(400)
                .body("status", equalTo(400))
                .body("message", equalTo("Malformed JSON request"))
                .body("path", equalTo("/api/loans"));
    }
}

package com.qa.tests.tests.functional;

import com.qa.tests.base.BaseApiTest;
import com.qa.tests.utils.TestDataFactory;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;

@Tag("functional")
class FunctionalTests extends BaseApiTest {

    @Test
    void getAllLoans_returns200WithJsonArray() {
        loanClient.getLoans()
                .then()
                .statusCode(200)
                .contentType("application/json");
    }

    @Test
    void getLoanById_returnsCorrectLoan() {
        loanClient.getLoan(102)
                .then()
                .statusCode(200)
                .body("id", equalTo(102))
                .body("customerName", equalTo("Amit"))
                .body("status", equalTo("PENDING"));
    }

    @Test
    void createUpdateAndDeleteLoan_fullLifecycle() {
        int loanId = loanClient.createLoan(TestDataFactory.validLoan())
                .then()
                .statusCode(201)
                .body("status", equalTo("PENDING"))
                .extract()
                .path("id");

        loanClient.updateLoanStatus(loanId, TestDataFactory.statusUpdate("APPROVED"))
                .then()
                .statusCode(200)
                .body("id", equalTo(loanId))
                .body("status", equalTo("APPROVED"));

        loanClient.getLoan(loanId)
                .then()
                .statusCode(200)
                .body("status", equalTo("APPROVED"));

        loanClient.deleteLoan(loanId)
                .then()
                .statusCode(204);

        loanClient.getLoan(loanId)
                .then()
                .statusCode(404);
    }

    @Test
    void updateLoanStatus_toRejected() {
        int loanId = loanClient.createLoan(TestDataFactory.validLoan())
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        loanClient.updateLoanStatus(loanId, TestDataFactory.statusUpdate("REJECTED"))
                .then()
                .statusCode(200)
                .body("status", equalTo("REJECTED"));

        loanClient.deleteLoan(loanId).then().statusCode(204);
    }

    @Test
    void createLoan_generatesUniqueId() {
        int id1 = loanClient.createLoan(TestDataFactory.validLoan())
                .then().statusCode(201).extract().path("id");
        int id2 = loanClient.createLoan(TestDataFactory.validLoan())
                .then().statusCode(201).extract().path("id");

        org.assertj.core.api.Assertions.assertThat(id2).isGreaterThan(id1);

        loanClient.deleteLoan(id1).then().statusCode(204);
        loanClient.deleteLoan(id2).then().statusCode(204);
    }
}

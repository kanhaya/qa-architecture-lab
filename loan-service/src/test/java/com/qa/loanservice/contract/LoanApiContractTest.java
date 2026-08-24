package com.qa.loanservice.contract;

import com.atlassian.oai.validator.restassured.OpenApiValidationFilter;
import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

import java.util.Objects;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class LoanApiContractTest {

    private static final OpenApiValidationFilter OPENAPI_FILTER = new OpenApiValidationFilter(
            Objects.requireNonNull(
                    LoanApiContractTest.class.getClassLoader().getResource("openapi/loan-service.yaml"),
                    "openapi/loan-service.yaml must be on the classpath"
            ).toString()
    );

    @LocalServerPort
    private int port;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
    }

    @Test
    void getLoans_matchesContract() {
        given()
                .filter(OPENAPI_FILTER)
                .accept(ContentType.JSON)
                .when()
                .get("/api/loans")
                .then()
                .statusCode(200)
                .body("size()", greaterThan(0));
    }

    @Test
    void getLoanById_matchesContract() {
        given()
                .filter(OPENAPI_FILTER)
                .accept(ContentType.JSON)
                .when()
                .get("/api/loans/{id}", 101)
                .then()
                .statusCode(200)
                .body("id", equalTo(101))
                .body("customerName", equalTo("Rahul"));
    }

    @Test
    void getLoanById_notFound_matchesContract() {
        given()
                .filter(OPENAPI_FILTER)
                .accept(ContentType.JSON)
                .when()
                .get("/api/loans/{id}", 99999)
                .then()
                .statusCode(404);
    }

    @Test
    void createLoan_matchesContract() {
        given()
                .filter(OPENAPI_FILTER)
                .contentType(ContentType.JSON)
                .accept(ContentType.JSON)
                .body("{\"customerName\":\"Contract User\",\"amount\":250000}")
                .when()
                .post("/api/loans")
                .then()
                .statusCode(201)
                .body("status", equalTo("PENDING"));
    }

    @Test
    void updateStatus_matchesContract() {
        given()
                .filter(OPENAPI_FILTER)
                .contentType(ContentType.JSON)
                .accept(ContentType.JSON)
                .body("{\"status\":\"APPROVED\"}")
                .when()
                .put("/api/loans/{id}/status", 102)
                .then()
                .statusCode(200)
                .body("status", equalTo("APPROVED"));
    }

    @Test
    void deleteLoan_matchesContract() {
        Integer id = given()
                .filter(OPENAPI_FILTER)
                .contentType(ContentType.JSON)
                .accept(ContentType.JSON)
                .body("{\"customerName\":\"To Delete\",\"amount\":1000}")
                .when()
                .post("/api/loans")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .filter(OPENAPI_FILTER)
                .when()
                .delete("/api/loans/{id}", id)
                .then()
                .statusCode(204);
    }

    @Test
    void health_matchesContract() {
        given()
                .filter(OPENAPI_FILTER)
                .accept(ContentType.JSON)
                .when()
                .get("/actuator/health")
                .then()
                .statusCode(200)
                .body("status", equalTo("UP"));
    }
}

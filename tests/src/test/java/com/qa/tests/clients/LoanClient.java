package com.qa.tests.clients;

import com.qa.tests.utils.TestConfig;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;

import java.util.Map;

import static io.restassured.RestAssured.given;

public class LoanClient {

    private final String baseUrl;

    public LoanClient() {
        this(TestConfig.getBaseUrl());
    }

    public LoanClient(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    public Response getHealth() {
        return given()
                .baseUri(baseUrl)
                .when()
                .get("/actuator/health");
    }

    public Response getLoans() {
        return request()
                .when()
                .get("/api/loans");
    }

    public Response getLoan(long id) {
        return request()
                .when()
                .get("/api/loans/" + id);
    }

    public Response createLoan(Map<String, Object> loanRequest) {
        return request()
                .body(loanRequest)
                .when()
                .post("/api/loans");
    }

    public Response createLoanRaw(String jsonBody) {
        return request()
                .body(jsonBody)
                .when()
                .post("/api/loans");
    }

    public Response updateLoanStatus(long id, Map<String, Object> statusRequest) {
        return request()
                .body(statusRequest)
                .when()
                .put("/api/loans/" + id + "/status");
    }

    public Response updateLoanStatusRaw(long id, String jsonBody) {
        return request()
                .body(jsonBody)
                .when()
                .put("/api/loans/" + id + "/status");
    }

    public Response deleteLoan(long id) {
        return request()
                .when()
                .delete("/api/loans/" + id);
    }

    private RequestSpecification request() {
        return given()
                .baseUri(baseUrl)
                .contentType(ContentType.JSON)
                .accept(ContentType.JSON);
    }
}

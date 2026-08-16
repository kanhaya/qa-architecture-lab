package com.qa.tests.utils;

import java.util.HashMap;
import java.util.Map;

public final class TestDataFactory {

    private TestDataFactory() {
    }

    public static Map<String, Object> validLoan() {
        Map<String, Object> loan = new HashMap<>();
        loan.put("customerName", "Test Customer");
        loan.put("amount", 250_000);
        return loan;
    }

    public static Map<String, Object> invalidLoanMissingName() {
        Map<String, Object> loan = new HashMap<>();
        loan.put("amount", 250_000);
        return loan;
    }

    public static Map<String, Object> invalidLoanEmptyName() {
        Map<String, Object> loan = new HashMap<>();
        loan.put("customerName", "");
        loan.put("amount", 250_000);
        return loan;
    }

    public static Map<String, Object> invalidLoanShortName() {
        Map<String, Object> loan = new HashMap<>();
        loan.put("customerName", "A");
        loan.put("amount", 250_000);
        return loan;
    }

    public static Map<String, Object> zeroAmountLoan() {
        Map<String, Object> loan = new HashMap<>();
        loan.put("customerName", "Zero Amount");
        loan.put("amount", 0);
        return loan;
    }

    public static Map<String, Object> negativeAmountLoan() {
        Map<String, Object> loan = new HashMap<>();
        loan.put("customerName", "Negative Amount");
        loan.put("amount", -1000);
        return loan;
    }

    public static Map<String, Object> largeAmountLoan() {
        Map<String, Object> loan = new HashMap<>();
        loan.put("customerName", "Large Amount");
        loan.put("amount", 10_000_001);
        return loan;
    }

    public static Map<String, Object> invalidStatusUpdate() {
        Map<String, Object> request = new HashMap<>();
        request.put("status", "INVALID_STATUS");
        return request;
    }

    public static Map<String, Object> statusUpdate(String status) {
        Map<String, Object> request = new HashMap<>();
        request.put("status", status);
        return request;
    }
}

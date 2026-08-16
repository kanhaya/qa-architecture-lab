package com.qa.tests.utils;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;

public final class TestConfig {

    private static final String DEFAULT_BASE_URL = "http://localhost:8081";
    private static final String[] BASE_URL_CANDIDATES = {
            "http://localhost:8081",
            "http://localhost:30080",
            "http://127.0.0.1:8081",
            "http://127.0.0.1:30080",
            "http://[::1]:8081"
    };

    private TestConfig() {
    }

    public static String getBaseUrl() {
        String baseUrl = System.getenv("BASE_URL");
        if (baseUrl != null && !baseUrl.isBlank()) {
            return normalize(baseUrl);
        }

        baseUrl = System.getProperty("BASE_URL");
        if (baseUrl != null && !baseUrl.isBlank()) {
            return normalize(baseUrl);
        }

        for (String candidate : BASE_URL_CANDIDATES) {
            if (isLoanServiceHealthy(candidate)) {
                return candidate;
            }
        }

        return DEFAULT_BASE_URL;
    }

    public static String getEnvironment() {
        String env = System.getProperty("env");
        if (env != null && !env.isBlank()) {
            return env;
        }
        env = System.getenv("TEST_ENV");
        if (env != null && !env.isBlank()) {
            return env;
        }
        return "local";
    }

    private static String normalize(String baseUrl) {
        return baseUrl.replaceAll("/$", "");
    }

    private static boolean isLoanServiceHealthy(String baseUrl) {
        try {
            HttpURLConnection connection = (HttpURLConnection) URI.create(baseUrl + "/actuator/health")
                    .toURL()
                    .openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(2000);
            connection.setReadTimeout(2000);
            int status = connection.getResponseCode();
            if (status != 200) {
                connection.disconnect();
                return false;
            }

            try (InputStream inputStream = connection.getInputStream()) {
                String body = new String(inputStream.readAllBytes(), StandardCharsets.UTF_8);
                return body.contains("\"status\":\"UP\"");
            } finally {
                connection.disconnect();
            }
        } catch (Exception ignored) {
            return false;
        }
    }
}

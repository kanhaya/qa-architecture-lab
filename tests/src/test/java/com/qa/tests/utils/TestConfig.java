package com.qa.tests.utils;

import java.net.HttpURLConnection;
import java.net.URI;

public final class TestConfig {

    private static final String DEFAULT_BASE_URL = "http://localhost:8080";
    private static final String[] BASE_URL_CANDIDATES = {
            "http://localhost:8080",
            "http://[::1]:8080",
            "http://127.0.0.1:8080"
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
            if (isHealthy(candidate)) {
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

    private static boolean isHealthy(String baseUrl) {
        try {
            HttpURLConnection connection = (HttpURLConnection) URI.create(baseUrl + "/actuator/health")
                    .toURL()
                    .openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(2000);
            connection.setReadTimeout(2000);
            int status = connection.getResponseCode();
            connection.disconnect();
            return status == 200;
        } catch (Exception ignored) {
            return false;
        }
    }
}

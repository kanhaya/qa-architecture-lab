package com.qa.loanservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.actuate.info.Info;
import org.springframework.boot.actuate.info.InfoContributor;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
public class AppInfoContributor implements InfoContributor {

    @Value("${spring.application.name}")
    private String applicationName;

    @Value("${app.env}")
    private String environment;

    @Value("${project.version:1.0.0}")
    private String version;

    @Override
    public void contribute(Info.Builder builder) {
        builder.withDetail("app", Map.of(
                "name", applicationName,
                "version", version,
                "environment", environment
        ));
    }
}

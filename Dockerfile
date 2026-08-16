# Build stage
FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /build

COPY pom.xml .
COPY loan-service/pom.xml loan-service/
COPY tests/pom.xml tests/

RUN apk add --no-cache maven

COPY loan-service/src loan-service/src

RUN mvn -f pom.xml -pl loan-service -am clean package -DskipTests -q

# Runtime stage
FROM eclipse-temurin:21-jre-alpine

RUN apk add --no-cache curl \
    && addgroup -S appgroup \
    && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=build /build/loan-service/target/loan-service-*.jar app.jar

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

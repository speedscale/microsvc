# Multi-stage build for User Service
FROM --platform=$BUILDPLATFORM maven:3-amazoncorretto-20 AS builder

WORKDIR /app

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Runtime image
FROM --platform=$TARGETPLATFORM amazoncorretto:20-alpine

WORKDIR /app

# Install curl for health checks and create non-root user
RUN apk add --no-cache curl && \
    addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001

# Copy the built JAR file
COPY --from=builder /app/target/user-service-*.jar app.jar

# Create logs directory
RUN mkdir -p /var/log && \
    chown -R appuser:appuser /var/log /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application with optimized JVM flags for faster startup
ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-XX:+UseG1GC", \
    "-XX:+UseStringDeduplication", \
    "-XX:+OptimizeStringConcat", \
    "-XX:+UseCompressedOops", \
    "-XX:+UseCompressedClassPointers", \
    "-XX:+TieredCompilation", \
    "-XX:TieredStopAtLevel=1", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dspring.main.lazy-initialization=true", \
    "-Dspring.main.banner-mode=off", \
    "-Dlogging.level.org.springframework.boot.autoconfigure=WARN", \
    "-Dlogging.level.io.opentelemetry=WARN", \
    "-jar", "/app/app.jar"]
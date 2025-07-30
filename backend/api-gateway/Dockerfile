# Multi-stage build for API Gateway
FROM --platform=$BUILDPLATFORM maven:3-amazoncorretto-17 AS builder

WORKDIR /app

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Extract layers from the JAR
RUN java -Djarmode=layertools -jar target/api-gateway-*.jar extract

# Runtime image - use Amazon Corretto Alpine for Colima compatibility
FROM --platform=$TARGETPLATFORM amazoncorretto:17-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 spring && \
    adduser -D -s /bin/sh -u 1001 -G spring spring

# Copy layers in order of likelihood to change (dependencies first, then application)
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/snapshot-dependencies/ ./
COPY --from=builder /app/application/ ./

# Change ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring

# Expose port
EXPOSE 80

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
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dspring.main.lazy-initialization=true", \
    "-Dspring.main.banner-mode=off", \
    "-Dlogging.level.org.springframework.boot.autoconfigure=WARN", \
    "-Dlogging.level.io.opentelemetry=WARN", \
    "org.springframework.boot.loader.JarLauncher"]
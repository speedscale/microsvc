# Multi-stage build for Transactions Service
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
FROM --platform=$TARGETPLATFORM gcr.io/distroless/java20-debian12

WORKDIR /app

# Copy the built JAR file
COPY --from=builder /app/target/transactions-service-*.jar app.jar

# Switch to non-root user (distroless default is nonroot:65534)
USER 65534

# Expose port
EXPOSE 8080

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
    "-jar", "/app/app.jar"]
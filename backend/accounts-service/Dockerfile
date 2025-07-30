# Multi-stage build for Accounts Service
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
RUN java -Djarmode=layertools -jar target/accounts-service-*.jar extract

# Runtime image
FROM --platform=$TARGETPLATFORM gcr.io/distroless/java17-debian12

WORKDIR /app

# Copy layers in order of likelihood to change (dependencies first, then application)
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/snapshot-dependencies/ ./
COPY --from=builder /app/application/ ./

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
    "org.springframework.boot.loader.JarLauncher"]
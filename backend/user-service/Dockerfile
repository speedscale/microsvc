FROM --platform=$BUILDPLATFORM maven:3-amazoncorretto-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

FROM --platform=$TARGETPLATFORM amazoncorretto:17-alpine
COPY --from=build /app/target/user-service-*.jar /app/user-service.jar
RUN addgroup -g 1001 spring && \
    adduser -D -s /bin/sh -u 1001 -G spring spring && \
    chown -R spring:spring /app
USER spring
EXPOSE 8080
ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-XX:+UseSerialGC", \
    "-XX:MaxMetaspaceSize=96m", \
    "-XX:ReservedCodeCacheSize=32m", \
    "-XX:+UseStringDeduplication", \
    "-XX:+OptimizeStringConcat", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dspring.main.lazy-initialization=true", \
    "-jar", "/app/user-service.jar"]

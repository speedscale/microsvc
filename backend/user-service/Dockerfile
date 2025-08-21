FROM maven:3-amazoncorretto-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

FROM gcr.io/distroless/java17-debian12
COPY --from=build /app/target/user-service-*.jar /app/user-service.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/user-service.jar"]

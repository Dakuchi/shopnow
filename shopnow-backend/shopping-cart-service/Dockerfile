# Stage 1: Build the application
FROM openjdk:17-jdk-slim AS builder

WORKDIR /app
COPY . .
RUN ./mvnw clean package -DskipTests

# Stage 2: Run the application
FROM openjdk:17-jdk-slim

WORKDIR /app
COPY --from=builder /app/target/shopping-cart-service-0.0.1-SNAPSHOT.war /app/shopping-cart-service.war

CMD ["java", "-jar", "shopping-cart-service.war"]

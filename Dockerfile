FROM maven:3.8.5-openjdk-17 AS build
WORKDIR /app
COPY . .
RUN mvn -version

FROM openjdk:17-jdk-alpine
WORKDIR /app
EXPOSE 8080
#CMD ["java", "-jar", "app.jar"]
# Use a lightweight Alpine
FROM alpine:latest

#update dependecies
RUN apk update && apk add --no-cache openjdk17

# Set working directory
WORKDIR /tmp

# Copy the built JAR file from the host machine into the container
COPY target/htmx-demo.jar /app/app.jar

# Expose application port
EXPOSE 8080

# Command to run the Spring Boot application
CMD ["java", "-jar", "/app/app.jar"]
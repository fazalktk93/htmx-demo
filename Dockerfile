# Use Alpine with Maven and OpenJDK
FROM alpine:latest

# Install required dependencies
RUN apk update && apk add --no-cache openjdk17 maven

# Set working directory
WORKDIR /app

# Copy the entire project source code
COPY . .

# Expose application port
EXPOSE 8080

# Run the application using Maven
CMD ["mvn", "spring-boot:run"]
# Use a Java base image
#FROM maven:3.9.6-eclipse-temurin-17
FROM openjdk:17-jdk-alpine

# Set the working directory inside the container
WORKDIR /app

# Copy the application files to the container
COPY . .

# Install Maven (not needed if using a Maven-based image)
RUN apk add --no-cache maven curl
#RUN yum update -y
#RUN yum install -y yum-utils
#RUN yum-config-manager --add-repo https://repos.fedorapeople.org/dchen/apache-maven/epel-apache-maven.repo
#RUN yum-config-manager --enable epel-apache-maven
#RUN yum install maven -y
#RUN wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
#RUN yum install maven -y

# Build the application
#RUN mvn clean package

# Expose the application port
#EXPOSE 8080

# Run the Spring Boot application
#CMD ["sh", "-c", "mvn spring-boot:run"]
RUN mvn spring-boot:run

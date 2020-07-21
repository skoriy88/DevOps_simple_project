FROM openjdk:8-jdk-alpine
WORKDIR /my_app
ARG WAR_FILE=target/*.war
COPY ${WAR_FILE} app.war
ENTRYPOINT ["java","-jar","/app.war", "--server.port=9999"]
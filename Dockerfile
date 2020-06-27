FROM adoptopenjdk:8-jdk-hotspot
COPY build/libs/spring-petclinic-data-jdbc-2.1.0.BUILD-SNAPSHOT.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app.jar"]

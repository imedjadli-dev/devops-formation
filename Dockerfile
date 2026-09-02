FROM eclipse-temurin:17-jdk

COPY target/achat-1.0.jar achat-1.0.jar

EXPOSE 8282

ENTRYPOINT ["java", "-jar", "/achat-1.0.jar"]
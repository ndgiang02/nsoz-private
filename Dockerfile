FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -DskipTests package

FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends xvfb libxrender1 libxtst6 libxi6 libxext6 libfreetype6 fontconfig \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /build/target/Nso-jar-with-dependencies.jar /app/app.jar
COPY Data /app/Data
COPY docker/server/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 14444
ENTRYPOINT ["/app/entrypoint.sh"]

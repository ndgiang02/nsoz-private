FROM mariadb:10.6

COPY database/database.sql /tmp/database.sql
RUN set -eux; \
    { \
      echo "CREATE DATABASE IF NOT EXISTS nsoz2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; \
      echo "USE nsoz2;"; \
      cat /tmp/database.sql; \
    } > /docker-entrypoint-initdb.d/01-nsoz2.sql; \
    rm /tmp/database.sql


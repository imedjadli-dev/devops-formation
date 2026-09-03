FROM eclipse-temurin:17-jdk

# Installer PostgreSQL + supervisor pour lancer les deux process
RUN apt-get update && \
    apt-get install -y postgresql postgresql-contrib supervisor && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Initialiser PostgreSQL
ENV PGDATA=/var/lib/postgresql/18/main
RUN service postgresql start && \
    su postgres -c "psql -c \"ALTER USER postgres PASSWORD 'root';\"" && \
    su postgres -c "psql -c \"CREATE DATABASE devopsdb;\"" && \
    service postgresql stop

# Copier ton jar
COPY target/*.jar achat.jar

# Config supervisor pour lancer postgres + spring boot ensemble
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 8282 5432

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
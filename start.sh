#!/bin/bash

set -eu

readonly SONARQUBE_CONFIG_DIR="/opt/sonarqube/conf"

sed -e "s/##POSTGRESQL_DATABASE/${CLOUDRON_POSTGRESQL_DATABASE}/" \
    -e "s/##POSTGRESQL_USERNAME/${CLOUDRON_POSTGRESQL_USERNAME}/" \
    -e "s/##POSTGRESQL_PASSWORD/${CLOUDRON_POSTGRESQL_PASSWORD}/" \
    -e "s/##POSTGRESQL_HOST/${CLOUDRON_POSTGRESQL_HOST}/" \
    -e "s/##POSTGRESQL_PORT/${CLOUDRON_POSTGRESQL_PORT}/" \
    -e "s/##MAIL_SMTP_SERVER/${CLOUDRON_MAIL_SMTP_SERVER}/g" \
    -e "s/##MAIL_SMTP_PORT/${CLOUDRON_MAIL_SMTP_PORT}/g" \
    -e "s/##MAIL_SMTP_USERNAME/${CLOUDRON_MAIL_SMTP_USERNAME}/g" \
    -e "s/##MAIL_SMTP_PASSWORD/${CLOUDRON_MAIL_SMTP_PASSWORD}/g" \
    -e "s/##MAIL_DOMAIN/${CLOUDRON_MAIL_DOMAIN}/g" \
    -e "s/##MAIL_FROM/${CLOUDRON_MAIL_FROM}/g" \
    -e "s/##ROOT_URL/${CLOUDRON_APP_ORIGIN}/g" \
        /home/git/config_templates/sonar.properties > "${SONARQUBE_CONFIG_DIR}/sonar.properties"

echo "==> Starting SonarQube"
exec /opt/java/openjdk/bin/java -jar lib/sonarqube.jar -Dsonar.log.console=true
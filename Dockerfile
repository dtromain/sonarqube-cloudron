FROM cloudron/base:4.2.0@sha256:46da2fffb36353ef714f97ae8e962bd2c212ca091108d768ba473078319a47f4

#
# Java setup
#
ENV JAVA_HOME /opt/java/openjdk
ENV PATH $JAVA_HOME/bin:$PATH

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8'

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        # curl required for historical reasons, see https://github.com/adoptium/containers/issues/255
        curl \
        wget \
        # java.lang.UnsatisfiedLinkError: libfontmanager.so: libfreetype.so.6: cannot open shared object file: No such file or directory
        # java.lang.NoClassDefFoundError: Could not initialize class sun.awt.X11FontManager
        # https://github.com/docker-library/openjdk/pull/235#issuecomment-424466077
        fontconfig \
        # utilities for keeping Ubuntu and OpenJDK CA certificates in sync
        # https://github.com/adoptium/containers/issues/293
        ca-certificates p11-kit \
        # jlink --strip-debug on 13+ needs objcopy: https://github.com/docker-library/openjdk/issues/351
        # Error: java.io.IOException: Cannot run program "objcopy": error=2, No such file or directory
        binutils \
        tzdata \
        # locales ensures proper character encoding and locale-specific behaviors using en_US.UTF-8
        locales \
    ; \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_VERSION jdk-17.0.10+7

RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
       aarch64|arm64) \
         ESUM='16080d055da0962fbd6b40f659a98a457cba3efa7ea716d5400cfebe8b935bf0'; \
         BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jre_aarch64_linux_hotspot_17.0.10_7.tar.gz'; \
         ;; \
       amd64|i386:x86-64) \
         ESUM='620cc0e7338f2722f3ed076ac65c0fafb575981426bac4e1970860e5e2d048f0'; \
         BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jre_x64_linux_hotspot_17.0.10_7.tar.gz'; \
         ;; \
       armhf|arm) \
         ESUM='0378bdf6769632b182b27ba4e53b17eaefefdbafa3845c15e1bd88a5aeec8442'; \
         BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jre_arm_linux_hotspot_17.0.10_7.tar.gz'; \
         ;; \
       ppc64el|powerpc:common64) \
         ESUM='4e18b60dba540b5c431ff03f74a1c73b22d83151f93b8768241d264d1a53582d'; \
         BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jre_ppc64le_linux_hotspot_17.0.10_7.tar.gz'; \
         ;; \
       s390x|s390:64-bit) \
         ESUM='c1b2fd232fc55e814479d7585d7ec45bae952a2f4137084f1d99f958c6880a49'; \
         BINARY_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jre_s390x_linux_hotspot_17.0.10_7.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    wget --progress=dot:giga -O /tmp/openjdk.tar.gz ${BINARY_URL}; \
    echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
    mkdir -p "$JAVA_HOME"; \
    tar --extract \
        --file /tmp/openjdk.tar.gz \
        --directory "$JAVA_HOME" \
        --strip-components 1 \
        --no-same-owner \
    ; \
    rm -f /tmp/openjdk.tar.gz ${JAVA_HOME}/lib/src.zip; \
    # https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
    find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    ldconfig; \
    # https://github.com/docker-library/openjdk/issues/212#issuecomment-420979840
    # https://openjdk.java.net/jeps/341
    java -Xshare:dump;

RUN set -eux; \
    echo "Verifying install ..."; \
    echo "java --version"; java --version; \
    echo "Complete."

#
# SonarQube setup
#
ARG SONARQUBE_VERSION=10.4.0.87286
ARG SONARQUBE_ZIP_URL=https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip
ENV DOCKER_RUNNING="true" \
    JAVA_HOME='/opt/java/openjdk' \
    SONARQUBE_HOME=/opt/sonarqube \
    SONAR_VERSION="${SONARQUBE_VERSION}" \
    SQ_DATA_DIR="/opt/sonarqube/data" \
    SQ_EXTENSIONS_DIR="/opt/sonarqube/extensions" \
    SQ_LOGS_DIR="/opt/sonarqube/logs" \
    SQ_TEMP_DIR="/opt/sonarqube/temp"

RUN set -eux; \
    useradd --system --uid 1001 --gid 0 sonarqube; \
    apt-get update; \
    apt-get --no-install-recommends -y install gnupg unzip curl bash fonts-dejavu; \
    echo "networkaddress.cache.ttl=5" >> "${JAVA_HOME}/conf/security/java.security"; \
    sed --in-place --expression="s?securerandom.source=file:/dev/random?securerandom.source=file:/dev/urandom?g" "${JAVA_HOME}/conf/security/java.security"; \
    # pub   2048R/D26468DE 2015-05-25
    #       Key fingerprint = F118 2E81 C792 9289 21DB  CAB4 CFCA 4A29 D264 68DE
    # uid                  sonarsource_deployer (Sonarsource Deployer) <infra@sonarsource.com>
    # sub   2048R/06855C1D 2015-05-25
    for server in $(shuf -e hkps://keys.openpgp.org \
                            hkps://keyserver.ubuntu.com) ; do \
        gpg --batch --keyserver "${server}" --recv-keys 679F1EE92B19609DE816FDE81DB198F93525EC1A && break || : ; \
    done; \
    mkdir --parents /opt; \
    cd /opt; \
    curl --fail --location --output sonarqube.zip --silent --show-error "${SONARQUBE_ZIP_URL}"; \
    curl --fail --location --output sonarqube.zip.asc --silent --show-error "${SONARQUBE_ZIP_URL}.asc"; \
    gpg --batch --verify sonarqube.zip.asc sonarqube.zip; \
    unzip -q sonarqube.zip; \
    mv "sonarqube-${SONARQUBE_VERSION}" sonarqube; \
    rm sonarqube.zip*; \
    rm -rf ${SONARQUBE_HOME}/bin/*; \
    ln -s "${SONARQUBE_HOME}/lib/sonar-application-${SONARQUBE_VERSION}.jar" "${SONARQUBE_HOME}/lib/sonarqube.jar"; \
    chmod -R 550 ${SONARQUBE_HOME}; \
    chmod -R 770 "${SQ_DATA_DIR}" "${SQ_EXTENSIONS_DIR}" "${SQ_LOGS_DIR}" "${SQ_TEMP_DIR}"; \
    apt-get remove -y gnupg unzip; \
    rm -rf /var/lib/apt/lists/*;

COPY entrypoint.sh ${SONARQUBE_HOME}/docker/

WORKDIR ${SONARQUBE_HOME}
EXPOSE 9000

USER sonarqube
STOPSIGNAL SIGINT

ENTRYPOINT ["/opt/sonarqube/docker/entrypoint.sh"]
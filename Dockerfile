# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# ActiveMQ Artemis

FROM eclipse-temurin:17-jre as builder
LABEL maintainer="Per Pascal Seeland <pascal.seeland@tik.uni-stuttgart.de"
# Make sure pipes are considered to determine success, see: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /opt

ENV ACTIVEMQ_ARTEMIS_VERSION 2.41.0

ENV ARTEMIS_USER artemis
ENV ARTEMIS_PASSWORD artemis
ENV ANONYMOUS_LOGIN false
ENV CREATE_ARGUMENTS --user ${ARTEMIS_USER} --password ${ARTEMIS_PASSWORD} --silent --http-host 0.0.0.0 --relax-jolokia

ENV BROKER_HOME /var/lib/artemis
ENV CONFIG_PATH ${BROKER_HOME}/etc


# add user and group for artemis
RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends \
    libaio1t64 wget && \
    rm -rf /var/lib/apt/lists/*

USER root

RUN mkdir /var/lib/artemis && chown -R ubuntu.ubuntu /var/lib/artemis
RUN  wget "https://repository.apache.org/content/repositories/releases/org/apache/activemq/apache-artemis/${ACTIVEMQ_ARTEMIS_VERSION}/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz" && \
     wget "https://repository.apache.org/content/repositories/releases/org/apache/activemq/apache-artemis/${ACTIVEMQ_ARTEMIS_VERSION}/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.asc" && \
     wget "http://apache.org/dist/activemq/KEYS" && \
     gpg --no-tty --import "KEYS" && \
     gpg --no-tty "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.asc" && \
     tar xfz "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz" && \
     ln -s "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}" "/opt/apache-artemis" && \
     rm -f "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz" "KEYS" "apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.asc"; 

USER ubuntu
WORKDIR /var/lib/artemis

RUN /opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}/bin/artemis create ${CREATE_ARGUMENTS} .


FROM eclipse-temurin:17-jre
LABEL maintainer="Pascal Seeland <pascal.seeland@tik.uni-stuttgart.de>"
ENV ACTIVEMQ_ARTEMIS_VERSION=2.41.0
ENV ACTIVEMQ_ARTEMIS_VERSION=$ACTIVEMQ_ARTEMIS_VERSION
ENV BROKER_HOME=/var/lib/artemis
ENV CONFIG_PATH=${BROKER_HOME}/etc

# add user and group for artemis
RUN apt-get -qq -o=Dpkg::Use-Pty=0 update && \
    apt-get -qq -o=Dpkg::Use-Pty=0 install -y --no-install-recommends libaio1t64 && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /var/lib/artemis && chown -R ubuntu.ubuntu /var/lib/artemis
USER ubuntu
COPY --from=builder "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}" "/opt/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}"
COPY --from=builder "/var/lib/artemis" "/var/lib/artemis"

# Web Server
EXPOSE 8161 \
# JMX Exporter
    9404 \
# Port for AMQP
    5672

WORKDIR /var/lib/artemis

COPY broker.xml etc

USER ubuntu

# Expose some outstanding folders
VOLUME ["/var/lib/artemis"]
WORKDIR /var/lib/artemis

ENTRYPOINT ["bin/artemis"]
CMD ["run"]

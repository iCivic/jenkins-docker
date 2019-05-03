FROM docker:dind

# A few reasons for installing distribution-provided OpenJDK:
#
#  1. Oracle.  Licensing prevents us from redistributing the official JDK.
#
#  2. Compiling OpenJDK also requires the JDK to be installed, and it gets
#     really hairy.
#
#     For some sample build times, see Debian's buildd logs:
#       https://buildd.debian.org/status/logs.php?pkg=openjdk-8

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

ENV JAVA_VERSION 8u171
ENV JAVA_ALPINE_VERSION 8.171.11-r0

RUN set -x \
	&& apk add --no-cache \
		openjdk8="$JAVA_ALPINE_VERSION" \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ]

# If you're reading this and have any feedback on how this image could be
# improved, please open an issue or a pull request so we can discuss it!
#
#   https://github.com/docker-library/openjdk/issues

# Docker里运行Docker docker in docker(dind)
# http://www.wantchalk.com/c/devops/docker/2017/05/24/docker-in-docer.html
# docker（18）：使用 dind 镜像，用docker jenkins 构建docker 镜像。
# https://blog.csdn.net/freewebsys/article/details/79756488
#################### 以上生成 openjdk:8u171-jdk-alpine3.8 ###########################

RUN apk add --no-cache git openssh-client curl unzip bash ttf-dejavu coreutils

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# 容器与云计算
# https://yeasy.gitbooks.io/docker_practice/cloud/
# ensure you use the same uid
# 基于alpine构建docker镜像修改时区
# https://www.jianshu.com/p/4e7553179a72
# 修改使用Alpine Linux的Docker容器的时区
# https://www.jianshu.com/p/cd1636c94f9f
# Docker openjdk-8-jdk-alpine 容器时间与jdk时区不同修改方法
# https://www.cnblogs.com/solooo/p/7832117.html
RUN echo 'http://mirrors.ustc.edu.cn/alpine/v3.5/main' > /etc/apk/repositories \
    && echo 'http://mirrors.ustc.edu.cn/alpine/v3.5/community' >>/etc/apk/repositories \
    && apk add -U tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && apk del tzdata \
    && addgroup -g ${gid} ${group} \
    && adduser -h "$JENKINS_HOME" -u ${uid} -G ${group} -s /bin/bash -D ${user}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_VERSION 0.14.0
ENV TINI_SHA 6c41ec7d33e857d4779f14d9c74924cab0c7973485d2972419a3b7c7620ff5fd

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha256sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy
COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

# jenkins version being bundled in this docker image
# https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.138.1}

# jenkins.war checksum, download will be validated using it
# sha256sum jenkins-war-2.138.1.war
ARG JENKINS_SHA=ecb84b6575e86957b902cce5e68e360e6b0768b0921baa405e61d314239e5b27

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -
  
RUN chmod +x /usr/local/bin/jenkins.sh \
    && chmod +x /usr/local/bin/plugins.sh \
    && chmod +x /usr/local/bin/install-plugins.sh

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

#USER ${user}
USER root
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
## ****************************** 参考资料 *****************************************
## 制作Docker Image: docker build -t idu/jenkins .
## 启动容器：docker run -d --name jenkins -p 8080:8080 -p 50000:50000 --env JENKINS_SLAVE_AGENT_PORT=50000 idu/jenkins
## docker run -d \
## --name jenkins \
## --restart=always \
## -p 5050:8080 \
## -p 50000:50000 \
## -v /var/jenkins_home:/var/jenkins_home \
## -v /var/run/docker.sock:/var/run/docker.sock \
## -v $(which docker):/usr/bin/docker \
## idu/jenkins
## 
## 另一种启动方式
## docker run -d \
## --name jenkins \
## --restart=always \
## -p 5050:8080 \
## -p 50000:50000 \
## -v /var/jenkins_home:/var/jenkins_home \
## -v /usr/local/jdk1.8.0_45:/usr/local/jdk \
## -v /var/run/docker.sock:/var/run/docker.sock \
## -v $(which docker):/var/bin/docker \
## -v ~/.ssh:/root/.ssh \
## idu/jenkins:latest


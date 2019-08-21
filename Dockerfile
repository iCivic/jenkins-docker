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
RUN echo 'http://mirrors.ustc.edu.cn/alpine/v3.8/main' > /etc/apk/repositories \
    && echo 'http://mirrors.ustc.edu.cn/alpine/v3.8/community' >>/etc/apk/repositories
	
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

ENV JAVA_VERSION 8u212
ENV JAVA_ALPINE_VERSION 8.212.04-r1

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
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8
# https://github.com/docker-library/python/issues/147
ENV PYTHONIOENCODING UTF-8

# install ca-certificates so that HTTPS works consistently
# other runtime dependencies for Python are installed later
RUN apk add --no-cache ca-certificates

ENV GPG_KEY C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF
ENV PYTHON_VERSION 2.7.16

RUN set -ex \
	&& apk add --no-cache --virtual .fetch-deps \
		gnupg \
		tar \
		xz \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& apk add --no-cache --virtual .build-deps  \
		bzip2-dev \
		coreutils \
		dpkg-dev dpkg \
		expat-dev \
		findutils \
		gcc \
		gdbm-dev \
		libc-dev \
		libffi-dev \
		libnsl-dev \
		libtirpc-dev \
		linux-headers \
		make \
		ncurses-dev \
		libressl-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
		tcl-dev \
		tk \
		tk-dev \
		zlib-dev \
# add build deps before removing fetch deps in case there's overlap
	&& apk del .fetch-deps \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-shared \
		--enable-unicode=ucs4 \
		--with-system-expat \
		--with-system-ffi \
	&& make -j "$(nproc)" \
# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
		EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000" \
	&& make install \
	\
	&& find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		| xargs -rt apk add --no-cache --virtual .python-rundeps \
	&& apk del .build-deps \
	\
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python \
	\
	&& python2 --version

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 19.1

COPY ./get-pip.py ./get-pip.py
RUN set -ex; \
	\
#	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
#	\
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py

# CMD ["python2"]
#################### 以上生成 python2:alpine3.8 ###########################

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
RUN echo 'http://mirrors.ustc.edu.cn/alpine/v3.8/main' > /etc/apk/repositories \
    && echo 'http://mirrors.ustc.edu.cn/alpine/v3.8/community' >>/etc/apk/repositories \
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


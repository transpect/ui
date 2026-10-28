FROM mcr.microsoft.com/openjdk/jdk:21-ubuntu

ARG BASEX_ADMIN_PASSWORD

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get -y install curl wget unzip emacs subversion git bash-completion make sysstat inotify-tools 

ENV BASEX_DIR=/opt/basex
ENV TRANSPECTDIR=/opt/transpect

RUN svn checkout https://subversion.le-tex.de/common/basex13 $BASEX_DIR

WORKDIR ${BASEX_DIR}

ENV APP_USER=basex
ENV APP_UID=90
ENV APP_GROUP=basex
ENV APP_GID=90

COPY docker/.basex $BASEX_DIR

RUN ./bin/basex -c "ALTER PASSWORD admin $BASEX_ADMIN_PASSWORD "
COPY src/floormanager $BASEX_DIR/webapp/transpectui
COPY src/repo/config.xqm $BASEX_DIR/install/transpectui/
COPY src/repo/config.xml $BASEX_DIR/install/transpectui/
COPY scripts/entrypoint.sh $BASEX_DIR

EXPOSE 8080
CMD ${BASEX_DIR}/entrypoint.sh

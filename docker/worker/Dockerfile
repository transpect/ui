FROM transpectui

ARG BASEX_ADMIN_PASSWORD
ARG WORKER_ID
ARG SVNPATH
ARG REV
ARG SVNUSER
ARG SVNPW

USER root

ENV DEBIAN_FRONTEND=noninteractive

ENV BASEX_DIR=/opt/basex
ENV TRANSPECTDIR=/opt/transpect

WORKDIR ${BASEX_DIR}

ENV APP_USER=basex
ENV APP_UID=90
ENV APP_GROUP=basex
ENV APP_GID=90

#add converter code
#COPY code/$WORKER_ID /opt/code
RUN svn checkout $SVNPATH -r $REV --username $SVNUSER --password $SVNPW /opt/code/$WORKER_ID
COPY src/transpectui $BASEX_DIR/webapp/transpectui
COPY src/repo $BASEX_DIR/install/transpectui
RUN find /opt/code/$WORKER_ID -name converter.xml -exec cp {} $BASEX_DIR/install/transpectui \;
COPY docker/worker/config.xml $BASEX_DIR/install/transpectui

RUN ./bin/basex -c "ALTER PASSWORD admin $BASEX_ADMIN_PASSWORD "
COPY scripts/entrypoint.sh $BASEX_DIR

EXPOSE 8080
CMD ${BASEX_DIR}/entrypoint.sh

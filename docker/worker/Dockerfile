FROM transpectui

ARG BASEX_ADMIN_PASSWORD
ARG WORKER_ID
ARG CONVERTER_XML

USER root

ENV DEBIAN_FRONTEND=noninteractive

ENV BASEX_DIR=/opt/basex
ENV TRANSPECTDIR=/opt/transpect

WORKDIR ${BASEX_DIR}

ENV APP_USER=basex
ENV APP_UID=90
ENV APP_GROUP=basex
ENV APP_GID=90

COPY docker/.basex $BASEX_DIR

#add converter code
COPY code/$WORKER_ID /opt/code
COPY src/transpectui $BASEX_DIR/webapp/transpectui
COPY $CONVERTER_XML $BASEX_DIR/webapp/transpectui
COPY docker/worker/config.xml $BASEX_DIR/webapp/transpectui

RUN ./bin/basex -c "ALTER PASSWORD admin $BASEX_ADMIN_PASSWORD "

EXPOSE 8080
CMD TIMEOUT=0 ./bin/basexhttp -h 8000 -s 8010

FROM alpine:3.11

MAINTAINER Sergey Fomin <sf@nagg.ru>

ENV KUBECTL_VERSION 1.18.2

RUN set -ex && \
    apk add --no-cache curl bash ncurses gawk && \
    curl -sSL https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

COPY scripts/kubelogin.sh scripts/hooklog.sh /usr/local/bin/


# syntax=docker/dockerfile:1
ARG IMAGE_PROXY=""
ARG DEBIAN_FRONTEND=noninteractive
ARG UBUNTU_VERSION="22.04"
ARG VERSION_NAME="reef"

FROM ${IMAGE_PROXY}ubuntu:${UBUNTU_VERSION} AS ceph
LABEL "com.clever-cloud"="Clever Cloud"
ENV TZ=Etc/UTC
ARG VERSION_NAME
ARG UBUNTU_VERSION
ENV UBUNTU_VERSION=${UBUNTU_VERSION}
ENV VERSION_NAME=${VERSION_NAME}

RUN apt -y update && apt -y install \
    lsb-release \
    wget \
    curl \
    pgp \
    tzdata \
    vim \
    dnsutils \
    iputils-ping \
    iproute2 \
    jq \
    patch

RUN wget \
    -q \
    -O- https://download.ceph.com/keys/release.asc | \
    gpg --dearmor > /etc/apt/trusted.gpg.d/ceph.gpg && \
    echo "deb https://download.ceph.com/debian-${VERSION_NAME}/ $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/ceph.list && \
    apt -y update && \
    apt install -y ceph radosgw

RUN apt clean && \
    apt autoremove -y && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

FROM ceph AS radosgw

ENV TZ=Etc/UTC
ENV ACCESS_KEY="radosgwadmin"
ENV SECRET_KEY="radosgwadmin"
ENV MGR_USERNAME="admin"
ENV MGR_PASSWORD="admin"
ENV MAIN="none"
ENV FEATURES="radosgw rbd"

EXPOSE 7480
EXPOSE 8080

COPY ./patches /patches
# Apply common patches, then the version-specific ones (reef/ or pacific/).
RUN set -e; \
    for d in /patches/common /patches/${VERSION_NAME}; do \
      for p in "$d"/*.patch; do \
        [ -e "$p" ] || continue; \
        echo "Applying $p"; \
        patch -p5 -d /usr/share/ceph/mgr/dashboard < "$p"; \
      done; \
    done

COPY ./entrypoint.sh /entrypoint
ENTRYPOINT /entrypoint

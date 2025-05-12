# syntax=docker/dockerfile:1
# Valid combinations:
#   reef    + 22.04 (default)
#   pacific + 20.04 (use --build-arg UBUNTU_VERSION=20.04 --build-arg VERSION_NAME=pacific)
ARG IMAGE_PROXY=""
ARG DEBIAN_FRONTEND=noninteractive
ARG UBUNTU_VERSION="22.04"
ARG VERSION_NAME="reef"

FROM ${IMAGE_PROXY}ubuntu:${UBUNTU_VERSION} AS ceph
ENV TZ=Etc/UTC
ARG VERSION_NAME
ARG UBUNTU_VERSION
ENV UBUNTU_VERSION=${UBUNTU_VERSION}
ENV VERSION_NAME=${VERSION_NAME}

# Validate Ceph/Ubuntu version combinations
RUN if [ "$VERSION_NAME" = "pacific" ] && [ "$UBUNTU_VERSION" != "20.04" ]; then \
    echo "ERROR: Ceph 'pacific' is only supported on Ubuntu 20.04" >&2; exit 1; \
    elif [ "$VERSION_NAME" = "reef" ] && [ "$UBUNTU_VERSION" != "22.04" ]; then \
    echo "ERROR: Ceph 'reef' is only supported on Ubuntu 22.04" >&2; exit 1; \
    fi

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
    jq

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

COPY ./entrypoint.sh /entrypoint
ENTRYPOINT /entrypoint

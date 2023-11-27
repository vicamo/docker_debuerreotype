# docker run --cap-add SYS_ADMIN --cap-drop SETFCAP --tmpfs /tmp:dev,exec,suid,noatime ...

# bootstrapping a new architecture?
#   ./scripts/debuerreotype-init /tmp/docker-rootfs bullseye now
#   ./scripts/debuerreotype-minimizing-config /tmp/docker-rootfs
#   ./scripts/debuerreotype-debian-sources-list /tmp/docker-rootfs bullseye
#   ./scripts/debuerreotype-tar /tmp/docker-rootfs - | docker import - debian:bullseye-slim
# alternate:
#   debootstrap --variant=minbase bullseye /tmp/docker-rootfs
#   tar -cC /tmp/docker-rootfs . | docker import - debian:bullseye-slim
# (or your own favorite set of "debootstrap" commands to create a base image for building this one FROM)
FROM debian:bullseye-slim

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		debootstrap \
		wget ca-certificates \
		xz-utils \
		\
		gnupg dirmngr \
	; \
	echo "deb http://deb.debian.org/debian unstable main" | tee /etc/apt/sources.list.d/unstable.list; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		debian-ports-archive-keyring/unstable \
	; \
	rm /etc/apt/sources.list.d/unstable.list; \
	rm -rf /var/lib/apt/lists/*

# fight the tyrrany of HSTS (which destroys our ability to transparently cache snapshot.debian.org responses)
ENV WGETRC /.wgetrc
RUN echo 'hsts=0' >> "$WGETRC"

# https://github.com/debuerreotype/debuerreotype/issues/100
# https://tracker.debian.org/pkg/distro-info-data
# http://snapshot.debian.org/package/distro-info-data/
# http://snapshot.debian.org/package/distro-info-data/0.51/
RUN set -eux; \
	wget -O distro-info-data.deb 'http://snapshot.debian.org/archive/debian/20210724T033023Z/pool/main/d/distro-info-data/distro-info-data_0.51_all.deb'; \
	echo 'c5f4a3bd999d3d79612dfec285e4afc4f6248648 *distro-info-data.deb' | sha1sum --strict --check -; \
	apt-get install -y ./distro-info-data.deb; \
	rm distro-info-data.deb; \
	[ -s /usr/share/distro-info/debian.csv ]

# https://bugs.debian.org/973852
# https://salsa.debian.org/installer-team/debootstrap/-/merge_requests/63
# https://people.debian.org/~tianon/debootstrap-mr-63--download_main.patch
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends patch; \
	rm -rf /var/lib/apt/lists/*; \
	wget -O debootstrap-download-main.patch 'https://people.debian.org/~tianon/debootstrap-mr-63--download_main.patch'; \
	echo 'ceae8f508a9b49236fa4519a44a584e6c774aa0e4446eb1551f3b69874a4cde5 *debootstrap-download-main.patch' | sha256sum --strict --check -; \
	patch --input=debootstrap-download-main.patch /usr/share/debootstrap/functions; \
	rm debootstrap-download-main.patch

# see ".dockerignore"
COPY . /opt/debuerreotype
RUN set -eux; \
	cd /opt/debuerreotype/scripts; \
	for f in debuerreotype-*; do \
		ln -svL "$PWD/$f" "/usr/local/bin/$f"; \
	done; \
	version="$(debuerreotype-version)"; \
	[ "$version" != 'unknown' ]; \
	echo "debuerreotype version $version"

WORKDIR /tmp

# a few example md5sum values for amd64:

# debuerreotype-init --keyring /usr/share/keyrings/debian-archive-removed-keys.gpg test-stretch stretch 2017-05-08T00:00:00Z
# debuerreotype-tar test-stretch test-stretch.tar
# md5sum test-stretch.tar
#   694f02c53651673ebe094cae3bcbb06d
# ./docker-run.sh sh -euxc 'debuerreotype-init --keyring /usr/share/keyrings/debian-archive-removed-keys.gpg /tmp/rootfs stretch 2017-05-08T00:00:00Z; debuerreotype-tar /tmp/rootfs - | md5sum'

# debuerreotype-init --keyring /usr/share/keyrings/debian-archive-removed-keys.gpg test-jessie jessie 2017-05-08T00:00:00Z
# debuerreotype-tar test-jessie test-jessie.tar
# md5sum test-jessie.tar
#   354cedd99c08d213d3493a7cf0aaaad6
# ./docker-run.sh sh -euxc 'debuerreotype-init --keyring /usr/share/keyrings/debian-archive-removed-keys.gpg /tmp/rootfs jessie 2017-05-08T00:00:00Z; debuerreotype-tar /tmp/rootfs - | md5sum'

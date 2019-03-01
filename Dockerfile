FROM elixir:1.8-alpine

RUN apk add libsodium bash

RUN set -xe \
	&& PEERDNS_DOWNLOAD_URL="https://github.com/p2pstuff/PeerDNS/archive/master.zip" \
	&& buildDeps=' \
		ca-certificates \
		curl \
		make \
		git \
		gcc \
		libc-dev \
		libsodium-dev \
		npm \
	' \
	&& apk add --no-cache --virtual .build-deps $buildDeps \
	&& curl -fSL -o peerdns.zip $PEERDNS_DOWNLOAD_URL \
	&& mkdir -p /opt/peerdns \
	&& unzip -d /opt/peerdns peerdns.zip \
	&& rm peerdns.zip \
	&& cd /opt/peerdns/PeerDNS-master/ \
	&& mix local.hex --force \
	&& mix local.rebar --force \
	&& mix deps.get \
	&& touch config/config.exs \
	&& MIX_ENV=prod mix release --no-tar --env=docker \
	&& cp -r _build/prod/rel/peerdns/* /opt/peerdns \
	&& cd ui \
	&& npm install \
	&& npm run build \
	&& mkdir /opt/peerdns/ui \
	&& cp -r build /opt/peerdns/ui \
	&& cd /opt/peerdns \
	&& rm -r /opt/peerdns/PeerDNS-master \
	&& rm -r /root/.mix /root/.npm /root/.hex \
	&& apk del .build-deps

EXPOSE 53/udp
EXPOSE 14123
WORKDIR /opt/peerdns
CMD "/opt/peerdns/bin/peerdns" "foreground"

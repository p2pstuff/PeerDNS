FROM elixir:1.8-alpine

RUN apk add libsodium bash

RUN mkdir -p /opt/peerdns/data /opt/peerdns/ui
COPY mix.exs mix.lock /opt/peerdns/
COPY config /opt/peerdns/config
COPY lib /opt/peerdns/lib
COPY ui/package.json ui/package-lock.json /opt/peerdns/ui/
COPY ui/src /opt/peerdns/ui/src
COPY ui/public /opt/peerdns/ui/public

WORKDIR /opt/peerdns
ENV MIX_ENV prod

RUN set -xe \
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
	&& mix local.hex --force \
	&& mix local.rebar --force \
	&& mix deps.get \
	&& mix compile \
	&& cd ui \
	&& npm install \
	&& npm run build \
	&& mv build .build && rm -r * && mv .build build \
	&& rm -r /root/.npm /root/.hex \
	&& apk del .build-deps

EXPOSE 53/udp
EXPOSE 14123

CMD "mix" "run" "--no-halt" "--no-deps-check"


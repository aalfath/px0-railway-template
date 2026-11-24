# px0 for Railway: upstream px0 built from its pinned release commit, with Caddy
# in front for HTTP basic auth (px0 has no login of its own).
# Upstream publishes no container image, so we build the v0.1.21 tag here.

# ---- source: px0 v0.1.21, pinned by commit -------------------------------
FROM golang:1.25.14-trixie@sha256:2c4c60ef415fbfa5e90300722293bef36c5e63fae17570ce18f580af933dbd73 AS src
ARG PX0_VERSION=0.1.21
ARG PX0_COMMIT=f5c7e6709035ef5def148ab7c8b5f7db8646b94d
RUN git init -q /src && cd /src \
 && git fetch -q --depth 1 https://github.com/px0-ai/px0 "${PX0_COMMIT}" \
 && git checkout -q FETCH_HEAD \
 && test "$(git rev-parse HEAD)" = "${PX0_COMMIT}" \
 && test "$(tr -d ' \r\n' < VERSION)" = "${PX0_VERSION}" \
 && rm -r .git

# ---- web bundle (no npm dependencies) ------------------------------------
FROM node:22.23.5-alpine3.24@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a AS web
WORKDIR /src
COPY --from=src /src/scripts ./scripts
COPY --from=src /src/web ./web
RUN node ./scripts/build-web.js

# ---- static Go binary ----------------------------------------------------
FROM golang:1.25.14-alpine3.24@sha256:1ae0735f00daffa3aaf1363a5184c0d2dc55c78e3db4ec70241cdac97bf84b59 AS build
WORKDIR /src
COPY --from=src /src/go.mod /src/go.sum ./
RUN go mod download
COPY --from=src /src ./
# The whole built web/ folder: the binary embeds app.js AND workbench.js.
COPY --from=web /src/web ./web
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/px0 . \
 && /out/px0 -version

# ---- runtime -------------------------------------------------------------
FROM debian:trixie-20261123-slim@sha256:8aa5a7bf5a1955bddbe7d74fcdd0b91ab30e74362a8b73af672b0481b35b44a0
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git openssh-client tini \
 && rm -r /var/lib/apt/lists/* \
 && mkdir -p /data
COPY --from=caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 /usr/bin/caddy /usr/local/bin/caddy
COPY --from=build /out/px0 /usr/local/bin/px0
COPY Caddyfile /etc/px0/Caddyfile
COPY gitconfig /etc/gitconfig
COPY start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh && caddy version && px0 -version
ENV HOME=/data \
    PX0_INTERNAL_PORT=7777 \
    DO_NOT_TRACK=1 \
    PX0_TELEMETRY=off
WORKDIR /data
EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/usr/local/bin/start.sh"]

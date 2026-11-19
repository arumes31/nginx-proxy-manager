# This is a Dockerfile intended to be built using `docker buildx`
# for multi-arch support. Building with `docker build` may have unexpected results.

# This file assumes that the frontend has been built using ./scripts/frontend-build

ARG BASE_IMAGE=nginxproxymanager/nginx-full:certbot-node
FROM nginxproxymanager/testca AS testca

# TEMPORARY: OpenResty 1.31.8.1 in the base image bundles nginx 1.31.8, which is
# affected by CVE-2026-123007, CVE-2026-123633, CVE-2026-121810, CVE-2026-113425,
# CVE-2026-123634 and other issues fixed in nginx 1.31.9. Rebuild OpenResty on
# nginx 1.31.9 and replace the nginx binary. Remove this stage, the COPY below
# and docker/scripts/{build-openresty-patched,bump-openresty-nginx.sh} once the
# base image ships an OpenResty release based on nginx >= 1.31.9.
FROM debian:trixie-slim AS openresty
ARG OPENRESTY_VERSION=1.31.8.1
ARG OPENRESTY_SHA256=71db26db9e39a20ac86f627da6e5005ded47ff63a66f10ff6f7b258218c5a418
ARG NGINX_VERSION=1.31.9
# sha256 of https://github.com/nginx/nginx/archive/refs/tags/release-${NGINX_VERSION}.tar.gz
ARG NGINX_SHA256=5685eeba242229c0b4765216347374d4dfb76eef937317b8110535caea9ec8a6
# Same ngx_http_geoip2_module revision the base image builds (its master branch)
ARG GEOIP2_COMMIT=445df24ef3781e488cee3dfe8a1e111997fc1dfe
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	build-essential ca-certificates dos2unix git libmaxminddb-dev libpcre2-dev libssl-dev perl wget zlib1g-dev
COPY docker/scripts/bump-openresty-nginx.sh /tmp/bump-openresty-nginx.sh
COPY docker/scripts/build-openresty-patched /tmp/build-openresty-patched
RUN /tmp/build-openresty-patched

FROM $BASE_IMAGE

ARG TARGETPLATFORM
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_DATE

# See: https://github.com/just-containers/s6-overlay/blob/master/README.md
ENV SUPPRESS_NO_CONFIG_WARNING=1 \
	S6_BEHAVIOUR_IF_STAGE2_FAILS=1 \
	S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
	S6_FIX_ATTRS_HIDDEN=1 \
	S6_KILL_FINISH_MAXTIME=10000 \
	S6_VERBOSITY=1 \
	NODE_ENV=production \
	NPM_BUILD_VERSION="${BUILD_VERSION}" \
	NPM_BUILD_COMMIT="${BUILD_COMMIT}" \
	NPM_BUILD_DATE="${BUILD_DATE}" \
	NODE_OPTIONS="--openssl-legacy-provider"

RUN echo "fs.file-max = 65535" > /etc/sysctl.conf \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends jq logrotate \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# s6 overlay
COPY docker/scripts/install-s6 /tmp/install-s6
RUN /tmp/install-s6 "${TARGETPLATFORM}" && rm -f /tmp/install-s6

EXPOSE 80 81 443

COPY backend       /app
COPY frontend/dist /app/frontend
COPY docker/rootfs /
# TEMPORARY: patched nginx binary, see the "openresty" stage above
COPY --from=openresty /out/ /
RUN nginx -V 2>&1 | head -n 1

# Copy test CA cert for use in container and add to trusted certs from a self-signed CA
COPY --from=testca /home/step/certs/root_ca.crt /etc/ssl/certs/NginxProxyManager.crt
WORKDIR /etc/ssl/certs
RUN ln -s NginxProxyManager.crt 1d0e3f10.0 && update-ca-certificates

WORKDIR /app
RUN yarn install \
	&& yarn cache clean

# Remove frontend service not required for prod, dev nginx config as well
RUN rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/frontend /etc/nginx/conf.d/dev.conf \
	&& chmod 644 /etc/logrotate.d/nginx-proxy-manager

VOLUME [ "/data" ]
ENTRYPOINT [ "/init" ]

LABEL org.label-schema.schema-version="1.0" \
	org.label-schema.license="MIT" \
	org.label-schema.name="nginx-proxy-manager" \
	org.label-schema.description="Docker container for managing Nginx proxy hosts with a simple, powerful interface " \
	org.label-schema.url="https://github.com/jc21/nginx-proxy-manager" \
	org.label-schema.vcs-url="https://github.com/jc21/nginx-proxy-manager.git" \
	org.label-schema.cmd="docker run --rm -ti jc21/nginx-proxy-manager:latest"

# syntax=docker/dockerfile:labs
FROM alpine:3.20.3 AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG LUAJIT_INC=/usr/include/luajit-2.1
ARG LUAJIT_LIB=/usr/lib

ARG NGINX_VER=release-1.27.4
ARG OPENSSL_VER=openssl-3.1.7+quic

ARG DTR_VER=1.25.1
ARG RCP_VER=1.27.1

ARG NB_VER=master
ARG NF_VER=master
ARG HMNM_VER=v0.37
ARG NJS_VER=0.8.7
ARG NDK_VER=v0.3.3
ARG LNM_VER=v0.10.27
ARG LRC_VER=v0.1.30
ARG LRL_VER=v0.15
ARG NHG2M_VER=3.4
ARG NNTLM_VER=master

ARG LIBOQS_VER=0.11.0
ARG OQSPROVIDER_VER=0.7.0

WORKDIR /src
# Requirements
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates build-base patch cmake git libtool autoconf automake perl bash \
    libatomic_ops-dev zlib-dev luajit-dev pcre2-dev linux-headers yajl-dev libxml2-dev libxslt-dev curl-dev lmdb-dev libfuzzy2-dev lua5.1-dev lmdb-dev geoip-dev libmaxminddb-dev
# Openssl
RUN git clone https://github.com/quictls/openssl --branch "$OPENSSL_VER" /usr/local/openssl
# Nginx
RUN git clone --recursive https://github.com/freenginx/nginx --branch "$NGINX_VER" /src/nginx && \
    wget -q https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/master/nginx__dynamic_tls_records_"$DTR_VER"%2B.patch -O /src/nginx/1.patch && \
    wget -q https://raw.githubusercontent.com/openresty/openresty/master/patches/nginx-"$RCP_VER"-resolver_conf_parsing.patch -O /src/nginx/2.patch && \
    sed -i "s|freenginx|NPMplus|g" /src/nginx/src/core/nginx.h && \
    cd /src/nginx && \
    patch -p1 </src/nginx/1.patch && \
    patch -p1 </src/nginx/2.patch && \
    rm /src/nginx/*.patch && \
# modules
    git clone --recursive https://github.com/google/ngx_brotli --branch "$NB_VER" /src/ngx_brotli && \
    git clone --recursive https://github.com/aperezdc/ngx-fancyindex --branch "$NF_VER" /src/ngx-fancyindex && \
    git clone --recursive https://github.com/openresty/headers-more-nginx-module --branch "$HMNM_VER" /src/headers-more-nginx-module && \
    git clone --recursive https://github.com/nginx/njs --branch "$NJS_VER" /src/njs && \
    git clone --recursive https://github.com/vision5/ngx_devel_kit --branch "$NDK_VER" /src/ngx_devel_kit && \
    git clone --recursive https://github.com/openresty/lua-nginx-module --branch "$LNM_VER" /src/lua-nginx-module && \
    git clone --recursive https://github.com/openresty/lua-resty-core --branch "$LRC_VER" /src/lua-resty-core && \
    git clone --recursive https://github.com/openresty/lua-resty-lrucache --branch "$LRL_VER" /src/lua-resty-lrucache && \
    git clone --recursive https://github.com/leev/ngx_http_geoip2_module --branch "$NHG2M_VER" /src/ngx_http_geoip2_module && \
    git clone --recursive https://github.com/gabihodoroaga/nginx-ntlm-module --branch "$NNTLM_VER" /src/nginx-ntlm-module
# Configure
RUN cd /src/nginx && \
    /src/nginx/auto/configure \
    --build=freenginx \
    --with-compat \
    --with-threads \
    --with-file-aio \
    --with-libatomic \
    --with-pcre \
    --with-pcre-jit \
    --with-openssl-opt="no-legacy --libdir=lib" \
    --with-openssl="/usr/local/openssl" \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_geoip_module \
    --with-stream_realip_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_ssl_module \
    --with-http_geoip_module \
    --with-http_realip_module \
    --with-http_gunzip_module \
    --with-http_addition_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_geoip_module \
    --with-http_sub_module \
    --with-http_stub_status_module \
    --add-module=/src/ngx_brotli \
    --add-module=/src/ngx-fancyindex \
    --add-module=/src/headers-more-nginx-module \
    --add-module=/src/njs/nginx \
    --add-module=/src/ngx_devel_kit \
    --add-module=/src/lua-nginx-module \
    --add-module=/src/ngx_http_geoip2_module \
    --add-module=/src/nginx-ntlm-module
# Build & Install
RUN cd /src/nginx && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    cd /src/lua-resty-core && \
    make -j "$(nproc)" install PREFIX=/usr/local/nginx && \
    cd /src/lua-resty-lrucache && \
    make -j "$(nproc)" install PREFIX=/usr/local/nginx && \
    perl /usr/local/openssl/configdata.pm --dump
# OQS
RUN git clone https://github.com/open-quantum-safe/liboqs --branch "$LIBOQS_VER" /src/liboqs && \
    cd /src/liboqs && \
    cmake -DCMAKE_BUILD_TYPE=Release && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install
RUN git clone https://github.com/open-quantum-safe/oqs-provider --branch "$OQSPROVIDER_VER" /src/oqs-provider && \
    cd /src/oqs-provider && \
    cmake -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=/usr/local/openssl/.openssl && \
    make -j "$(nproc)" && \
    mv -v /src/oqs-provider/lib/oqsprovider.so /usr/local/openssl/.openssl/lib/ossl-modules
RUN cp -v /usr/local/openssl/apps/openssl.cnf /usr/local/openssl/.openssl/openssl.cnf && \
    sed -i "s|default = default_sect|default = default_sect\noqsprovider = oqsprovider_sect|g" /usr/local/openssl/.openssl/openssl.cnf && \
    sed -i "s|\[default_sect\]|\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n|g" /usr/local/openssl/.openssl/openssl.cnf
# strip files
RUN strip -s /usr/local/nginx/sbin/nginx && \
    strip -s /usr/local/openssl/.openssl/bin/openssl && \
    strip -s /usr/local/openssl/.openssl/lib/ossl-modules/oqsprovider.so
RUN find /usr/local/nginx -exec file {} \; | grep "not stripped" || true; \
    find /usr/local/openssl/.openssl -exec file {} \; | grep "not stripped" || true

FROM alpine:3.20.3
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
COPY --from=build /usr/local/nginx                               /usr/local/nginx
COPY --from=build /usr/local/openssl/.openssl                    /usr/local/openssl/.openssl
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates tzdata tini zlib luajit pcre2 libstdc++ yajl libxml2 libxslt libcurl lmdb libfuzzy2 lua5.1-libs geoip libmaxminddb-libs && \
    ln -s /usr/local/nginx/sbin/nginx /usr/local/bin/nginx && \
    ln -s /usr/local/openssl/.openssl/bin/openssl /usr/local/bin/openssl

ENV OPENSSL_CONF=/usr/local/openssl/.openssl/openssl.cnf
ENTRYPOINT ["tini", "--", "nginx"]
CMD ["-g", "daemon off;"]
EXPOSE 80/tcp
EXPOSE 81/tcp
EXPOSE 443/tcp
EXPOSE 443/udp

# syntax=docker/dockerfile:labs
FROM python:3.13.1-alpine3.21
ENV PYTHONUNBUFFERED=1
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
COPY --from=zoeyvid/nginx-quic:latest /usr/local/nginx                               /usr/local/nginx
COPY --from=zoeyvid/nginx-quic:latest /usr/local/openssl/.openssl                    /usr/local/openssl/.openssl
COPY --from=zoeyvid/nginx-quic:latest /usr/local/modsecurity/lib/libmodsecurity.so.3 /usr/local/modsecurity/lib/libmodsecurity.so.3
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

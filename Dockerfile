FROM alpine:3.8 as builder

ENV OSM2PGSQL_VERSION=0.96.0
ENV OSM2PGSQL_MD5SUM=c6abde50a99fd5eb1342532fd6e78306

RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk add --update \
            g++ \
            make \
            cmake \
            postgresql-dev \
            postgresql-contrib \
            postgis@testing \
            expat-dev \
            boost-dev \
            zlib-dev \
            bzip2-dev \
            lua5.1-dev \
            proj4-dev@testing \
            py2-psycopg2

RUN wget -O osm2pgsql-$OSM2PGSQL_VERSION.tar.gz https://github.com/openstreetmap/osm2pgsql/archive/$OSM2PGSQL_VERSION.tar.gz && \
    echo "$OSM2PGSQL_MD5SUM  osm2pgsql-$OSM2PGSQL_VERSION.tar.gz" | md5sum -c && \
    tar -xzf osm2pgsql-$OSM2PGSQL_VERSION.tar.gz

RUN mkdir build && cd build && \
    cmake ../osm2pgsql-$OSM2PGSQL_VERSION -DBUILD_TESTS=ON && \
    make -j$(nproc)

RUN mkdir -p /run/postgresql && \
    mkdir -p /tmp/psql-tablespace && \
    chown -R postgres \
      /build \
      /osm2pgsql-$OSM2PGSQL_VERSION \
      /run/postgresql \
      /tmp/psql-tablespace && \
    \
    su postgres -c 'pg_ctl init -D /var/lib/postgresql/data' && \
    su postgres -c 'pg_ctl start -D /var/lib/postgresql/data -l /var/lib/postgresql/postgresql.log' && \
    \
    psql -c "CREATE TABLESPACE tablespacetest LOCATION '/tmp/psql-tablespace'" -d postgres -U postgres && \
    \
    cd /build && \
    su postgres -c 'make check'

RUN cd /build && make install


FROM alpine:3.8

RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk add --update --no-cache boost expat postgresql-libs zlib libbz2 lua5.1 proj4@testing && \
    adduser -D osm

COPY --from=builder /usr/local/bin/osm2pgsql /usr/local/bin/osm2pgsql
COPY --from=builder /usr/local/share/man/man1/osm2pgsql.1 /usr/local/share/man/man1/osm2pgsql.1
COPY --from=builder /usr/local/share/osm2pgsql/default.style /usr/local/share/osm2pgsql/default.style
COPY --from=builder /usr/local/share/osm2pgsql/empty.style /usr/local/share/osm2pgsql/empty.style

USER osm
WORKDIR /home/osm

ENTRYPOINT ["/usr/local/bin/osm2pgsql"]
CMD ["--help"]

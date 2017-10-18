#FROM node:5.9.0-slim
#FROM node:8.6.0-stretch
FROM node:8.6.0-slim

MAINTAINER macservice

ENV FFMPEG_VERSION=3.3.4 \
    NASM_VERSION=2.13.01 \
    LAME_VERSION=3_99_5 \
    NGINX_VERSION=1.13.5 \
    NGINX_RTMP_VERSION=1.2.0 \

    SRC="/usr/local"

ENV LD_LIBRARY_PATH="${SRC}/lib" \
    PKG_CONFIG_PATH="${SRC}/lib/pkgconfig" \

    BUILDDEPS="autoconf automake gcc g++ libtool make nasm zlib1g-dev libssl-dev xz-utils cmake build-essential libpcre3-dev"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes curl git libpcre3 tar perl ca-certificates ${BUILDDEPS} && \
    rm -rf /var/lib/apt/lists/* && \

   # nasm
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    wget http://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.xz && \
    tar -xvf nasm-${NASM_VERSION}.tar.xz && \
    cd nasm-${NASM_VERSION} && \
    ./configure && \
    make && \
    make install && \
    rm -rf "${DIR}" && \

   # x264
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    git clone "git://git.videolan.org/x264.git" && \
    cd x264 && \
    ./configure \
        --prefix="${SRC}" \
        --bindir="${SRC}/bin" \
        --enable-static \
        --enable-shared \
        --disable-cli && \
    make && \
    make install && \
    ldconfig && \
    rm -rf "${DIR}" && \

    # libmp3lame
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    git clone https://github.com/rbrito/lame.git && \
    cd lame && \
    ./configure \
        --prefix="${SRC}" \
        --bindir="${SRC}/bin" \
        --enable-nasm \
        --disable-shared && \
    make -j"$(nproc)" && \
    make install && \
    make distclean && \
    rm -rf "${DIR}" &&\

    # ffmpeg
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    curl -LOks "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" && \
    tar xzvf "ffmpeg-${FFMPEG_VERSION}.tar.gz" && \
    cd "ffmpeg-${FFMPEG_VERSION}" && \
    ./configure \
        --prefix="${SRC}" \
        --extra-cflags='-I/x264' \
        --extra-ldflags='-I/usr/local/x264 -L/usr/local/x264 -ldl' \
        --bindir="${SRC}/bin" \
        --extra-libs=-ldl \
        --enable-nonfree \
        --enable-gpl \
        --enable-version3 \
        --enable-avresample \
        --enable-libmp3lame \
        --enable-libx264 \
        --enable-openssl \
        --enable-postproc \
        --enable-small \
        --disable-debug \
        --disable-doc \
        --disable-ffserver && \
    make -j"$(nproc)" && \
    make install && \
    make distclean && \
    hash -r && \
    cd tools && \
    make qt-faststart && \
    cp qt-faststart "${SRC}/bin" && \
    rm -rf "${DIR}" && \
    echo "${SRC}/lib" > "/etc/ld.so.conf.d/libc.conf" && \
    ffmpeg -buildconf && \

    # nginx-rtmp
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    curl -LOks "https://github.com/nginx/nginx/archive/release-${NGINX_VERSION}.tar.gz" && \
    tar xzvf "release-${NGINX_VERSION}.tar.gz" && \
    git clone https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git && \
    cd "nginx-release-${NGINX_VERSION}" && \
    auto/configure \
        --with-http_ssl_module \
        --add-module="../nginx-rtmp-module" && \
    make -j"$(nproc)" && \
    make install && \
    rm -rf "${DIR}" && \

    apt-get purge -y --auto-remove ${BUILDDEPS} && \
    rm -rf /tmp/*

COPY . /restreamer
WORKDIR /restreamer

RUN npm install -g bower grunt grunt-cli nodemon public-ip eslint && \
    npm install && \
    grunt build
#    npm prune --production && \
#    npm cache clean && \
#    bower cache clean --allow-root

ENV RS_USERNAME admin
ENV RS_PASSWORD datarhei
ENV STREAM_IP 127.0.0.1:554

EXPOSE 8080
EXPOSE 443
VOLUME ["/restreamer/db"]
VOLUME ["/ssl"]

CMD ["./run.sh"]

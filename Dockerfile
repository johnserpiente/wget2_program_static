FROM alpine:latest

# https://mirrors.alpinelinux.org/
RUN sed -i 's@dl-cdn.alpinelinux.org@ftp.halifax.rwth-aachen.de@g' /etc/apk/repositories

RUN apk update
RUN apk upgrade

# required liboqs 
RUN apk add --no-cache \
  gcc g++ make linux-headers musl-dev \
  zlib-dev zlib-static python3-dev \
  curl protobuf-c-dev nghttp2-dev nghttp2-static \
  libevent-dev libevent-static expat-dev expat-static \
  libtool autoconf automake perl git \
  zstd-static zstd-dev xz-static xz-dev \
  zlib-static zlib-dev bzip2-static bzip2-dev \
  libunistring-static libunistring-dev gpgme-dev \
  gettext lzip flex texinfo wget \
  libgpg-error-static libgpg-error-dev \
  libassuan-static libassuan-dev openssl-dev openssl-libs-static \
  libpsl-static libpsl-dev git libtool autoconf automake \
  pcre2-static pcre2-dev cmake ninja autoconf-archive bash

ENV XZ_OPT=-e9
COPY build-static-wget2.sh build-static-wget2.sh
RUN chmod +x ./build-static-wget2.sh
RUN bash ./build-static-wget2.sh

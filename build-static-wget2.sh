#! /bin/bash

# Salir inmediatamente si un comando falla
set -e

# Crear directorios de trabajo y de salida
WORKSPACE=/tmp/workspace
mkdir -p $WORKSPACE
mkdir -p /work/artifact

# =========================================================================
# 1. DEPENDENCIAS CRÍTICAS PARA GNUTLS (GMP, Nettle)
# =========================================================================

echo "--- Compilando GMP ---"
cd $WORKSPACE
curl -sL https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz | tar x --xz
cd gmp-6.3.0
LDFLAGS="-static --static -no-pie -s" ./configure --prefix=/usr --disable-shared --enable-static --disable-assembly
make -j$(nproc)
make install

echo "--- Compilando Nettle ---"
cd $WORKSPACE
curl -sL https://ftp.gnu.org/gnu/nettle/nettle-3.9.1.tar.gz | tar x --gzip
cd nettle-3.9.1
LDFLAGS="-static --static -no-pie -s" ./configure --prefix=/usr --disable-shared --enable-static --disable-documentation --disable-openssl --enable-gmp
make -j$(nproc)
make install

# =========================================================================
# 2. OTRAS DEPENDENCIAS (incluyendo las de GnuTLS y Wget2)
# =========================================================================

echo "--- Compilando libidn2 ---"
cd $WORKSPACE
curl -sL https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz | tar x --gzip
cd libidn2-2.3.8
LDFLAGS="-static --static -no-pie -s" ./configure --prefix=/usr --disable-doc --disable-nls --disable-shared --with-included-libunistring
make -j$(nproc)
make install

echo "--- Compilando GnuTLS ---"
# Se usa la versión estable 3.8.5. Tu log mostraba 3.8.10, que puede ser de desarrollo.
cd $WORKSPACE
curl -sL https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.5.tar.xz | tar x --xz
cd gnutls-3.8.5

# ==================== SOLUCIÓN DEFINITIVA AQUÍ ====================
# Usamos CFLAGS="-fno-analyzer" para desactivar por completo el analizador estático
# de GCC, que es el que genera la avalancha de advertencias y ralentiza todo.
CFLAGS="-fno-analyzer" LDFLAGS="-static --static -no-pie -s" ./configure --prefix=/usr \
    --with-included-libtasn1 \
    --without-p11-kit \
    --without-tpm \
    --disable-doc \
    --disable-nls \
    --disable-shared \
    --enable-static \
    --with-crypto-backend=nettle \
    --disable-tests \
    --disable-werror
# ==================================================================
make -j$(nproc)
make install

echo "--- Compilando brotli ---"
cd $WORKSPACE
git clone https://github.com/google/brotli.git
cd brotli
mkdir build
cd build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=OFF ..
ninja
ninja install

echo "--- Compilando lzlib ---"
cd $WORKSPACE
curl -sL https://download.savannah.gnu.org/releases/lzip/lzlib/lzlib-1.15.tar.gz | tar x --gzip
cd lzlib-1.15
LDFLAGS="-static --static -no-pie -s" ./configure --prefix=/usr
make -j$(nproc)
make install

echo "--- Compilando libmicrohttpd ---"
cd $WORKSPACE
curl -sL https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-1.0.2.tar.gz | tar x --gzip
cd libmicrohttpd-1.0.2
LDFLAGS="-static --static -no-pie -s" ./configure --prefix=/usr
make -j$(nproc)
make install

echo "--- Compilando libhsts ---"
cd $WORKSPACE
git clone https://gitlab.com/rockdaboot/libhsts
cd libhsts
autoreconf -fi
LDFLAGS="-static --static -no-pie -s" ./configure --prefix=/usr
make -j$(nproc)
make install

# =========================================================================
# 3. COMPILACIÓN FINAL DE WGET2 CON GNUTLS
# =========================================================================

echo "--- Compilando Wget2 con GnuTLS ---"
cd $WORKSPACE
git clone https://github.com/rockdaboot/wget2
cd wget2
git clone --recursive https://github.com/coreutils/gnulib.git
./bootstrap
LDFLAGS="-static --static -no-pie -s -lgnutls -lnettle -lhogweed -lgmp -lidn2 -lunistring -lbrotlienc -lbrotlidec -lbrotlicommon -lgpgmepp -lgpgme -lgpg-error -lassuan" \
./configure --with-ssl=gnutls --with-lzma --with-gpgme --prefix=/usr/local/wget2mm --with-bzip2 --enable-manylibs --disable-shared
make -j$(nproc)
make install

# =========================================================================
# 4. EMPAQUETADO Y COMPRESIÓN DEL BINARIO
# =========================================================================

echo "--- Empaquetando el artefacto ---"
cd /usr/local
echo "Tamaño del binario antes de UPX:"
ls -l -R wget2mm/bin
upx --keep --best --lzma wget2mm/bin/wget2
echo "Tamaño del binario después de UPX:"
ls -l -R wget2mm/bin
tar czf ./wget2.tar.gz wget2mm/bin/wget2
mv ./wget2.tar.gz /work/artifact/

echo "--- Compilación completada con éxito. Artefacto en /work/artifact/wget2.tar.gz ---"

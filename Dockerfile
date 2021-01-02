FROM lnk2past/turtleshell:latest

LABEL "repository"="https://github.com/Lnk2past/blueshell"
LABEL "homepage"="https://github.com/Lnk2past/blueshell"
LABEL "maintainer"="Lnk2past <Lnk2past@gmail.com>"

RUN echo "deb http://http.us.debian.org/debian/ testing non-free contrib main" >> /etc/apt/sources.list

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y build-essential gawk texinfo bison file wget rsync \
    -o APT::Immediate-Configure=0 && \
    apt-get clean -y

RUN mkdir /gcc_all

WORKDIR /gcc_all

RUN git clone --depth=1 https://github.com/raspberrypi/linux

RUN wget https://ftpmirror.gnu.org/binutils/binutils-2.31.tar.bz2 && tar xf binutils-2.31.tar.bz2 && rm binutils-2.31.tar.bz2
RUN wget https://ftpmirror.gnu.org/glibc/glibc-2.28.tar.bz2 && tar xf glibc-2.28.tar.bz2 && rm glibc-2.28.tar.bz2
RUN wget https://ftpmirror.gnu.org/gcc/gcc-8.3.0/gcc-8.3.0.tar.gz && tar xf gcc-8.3.0.tar.gz && rm gcc-8.3.0.tar.gz
RUN wget https://ftpmirror.gnu.org/gcc/gcc-10.2.0/gcc-10.2.0.tar.gz && tar xf gcc-10.2.0.tar.gz && rm gcc-10.2.0.tar.gz

WORKDIR /gcc_all/gcc-8.3.0
RUN ./contrib/download_prerequisites
RUN rm *.tar.*

WORKDIR /gcc_all/gcc-10.2.0
RUN ./contrib/download_prerequisites
RUN rm *.tar.*

WORKDIR /gcc_all
RUN  mkdir -p /opt/cross-pi-gcc

WORKDIR /gcc_all/linux

ENV PATH="/opt/cross-pi-gcc/bin:${PATH}"
ENV KERNEL="kernel7"

RUN make ARCH=arm INSTALL_HDR_PATH=/opt/cross-pi-gcc/arm-linux-gnueabihf headers_install

RUN mkdir /gcc_all/build-binutils
WORKDIR /gcc_all/build-binutils
RUN ../binutils-2.31/configure --prefix=/opt/cross-pi-gcc --target=arm-linux-gnueabihf --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib \
    && make -j 8 \
    && make install

RUN mkdir /gcc_all/build-gcc
WORKDIR /gcc_all/build-gcc
RUN ../gcc-8.3.0/configure --prefix=/opt/cross-pi-gcc --target=arm-linux-gnueabihf --enable-languages=c,c++,fortran --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib \
    && make -j8 all-gcc \
    && make install-gcc

RUN mkdir /gcc_all/build-glibc
WORKDIR /gcc_all/build-glibc
RUN ../glibc-2.28/configure --prefix=/opt/cross-pi-gcc/arm-linux-gnueabihf --build=$MACHTYPE --host=arm-linux-gnueabihf --target=arm-linux-gnueabihf --with-arch=armv6 --with-fpu=vfp --with-float=hard --with-headers=/opt/cross-pi-gcc/arm-linux-gnueabihf/include --disable-multilib libc_cv_forced_unwind=yes \
    && make install-bootstrap-headers=yes install-headers \
    && make -j8 csu/subdir_lib \
    && install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/arm-linux-gnueabihf/lib \
    && arm-linux-gnueabihf-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o /opt/cross-pi-gcc/arm-linux-gnueabihf/lib/libc.so \
    && touch /opt/cross-pi-gcc/arm-linux-gnueabihf/include/gnu/stubs.h

WORKDIR /gcc_all/build-gcc
RUN make -j8 all-target-libgcc \
    && make install-target-libgcc

WORKDIR /gcc_all/build-glibc
RUN make -j8 \
    && make install

WORKDIR /gcc_all/build-gcc
RUN make -j8 \
    && make install


RUN sed -i '66i #ifndef PATH_MAX' /gcc_all/gcc-10.2.0/libsanitizer/asan/asan_linux.cpp \
    && sed -i '67i #define PATH_MAX 4096' /gcc_all/gcc-10.2.0/libsanitizer/asan/asan_linux.cpp \
    && sed -i '68i #endif' /gcc_all/gcc-10.2.0/libsanitizer/asan/asan_linux.cpp

RUN mkdir /gcc_all/build-gcc10
WORKDIR /gcc_all/build-gcc10
RUN ../gcc-10.2.0/configure --prefix=/opt/cross-pi-gcc --target=arm-linux-gnueabihf --enable-languages=c,c++,fortran --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib \
    && make -j8 \
    && make install

WORKDIR /root/home/blueshell

# Dockerfile for Rocky Linux 9 toolchain builds
FROM rockylinux:9

LABEL maintainer simon.cook@embecosm.com

RUN dnf -y upgrade && dnf -y groupinstall 'Development tools' && \
    dnf config-manager --set-enabled crb && \
    dnf -y install dejagnu python3 python-unversioned-command texinfo wget which expat-devel rsync file \
    gawk zlib-devel ninja-build pkg-config glib2-devel

# Install cmake 3.26.4
RUN mkdir -p /tmp/cmake && cd /tmp/cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4.tar.gz && \
    tar xf cmake-3.26.4.tar.gz && cd cmake-3.26.4 && \
    ./bootstrap --parallel=$(nproc) -- -DCMAKE_USE_OPENSSL=OFF && \
    make -j$(nproc) && make install && \
    cd /tmp && rm -rf cmake

# There seems to be an issue with our testing when using DejaGnu 1.6.3,
# whereby testing multiple variations causes DejaGnu to fail. To work
# around this, install and use DejaGnu 1.6.2.
RUN mkdir -p /tmp/dejagnu && cd /tmp/dejagnu && \
    wget https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.2.tar.gz && \
    tar xf dejagnu-1.6.2.tar.gz && cd dejagnu-1.6.2 && \
    ./configure && make && make install && \
    cd /tmp && rm -rf dejagnu

# Some tests require the user running testing to exist and have a home directory
# These values match what the Embecosm Buildbot builders are set up to use
RUN useradd -m -u 1002 builder

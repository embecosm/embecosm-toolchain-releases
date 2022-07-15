# Dockerfile for Rocky Linux 9 toolchain builds
FROM rockylinux:9

LABEL maintainer simon.cook@embecosm.com

RUN dnf -y upgrade && dnf -y groupinstall 'Development tools' && \
     dnf config-manager --set-enabled crb && \
    dnf -y install dejagnu python3 python-unversioned-command cmake texinfo wget which expat-devel

# Some tests require the user running testing to exist and have a home directory
# These values match what the Embecosm Buildbot builders are set up to use
RUN useradd -m -u 1002 builder

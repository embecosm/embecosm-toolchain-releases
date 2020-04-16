# Dockerfile for CentOS 8 toolchain builds
FROM centos:centos8

LABEL maintainer simon.cook@embecosm.com

RUN dnf -y upgrade && dnf -y groupinstall 'Development tools' && \
    dnf config-manager --set-enabled PowerTools && \
    dnf -y install dejagnu texinfo wget which

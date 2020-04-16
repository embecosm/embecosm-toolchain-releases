# Dockerfile for CentOS 7 toolchain builds
FROM centos:centos7

LABEL maintainer simon.cook@embecosm.com

RUN yum -y upgrade && yum -y groupinstall 'Development tools' && \
    yum -y install dejagnu texinfo wget which

# Install newer toolchain components
RUN yum install -y centos-release-scl && yum install -y devtoolset-7

ENV PATH="/opt/rh/devtoolset-7/root/usr/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/rh/devtoolset-7/root/usr/lib64:/opt/rh/devtoolset-7/root/usr/lib:/opt/rh/devtoolset-7/root/usr/lib64/dyninst:/opt/rh/devtoolset-7/root/usr/lib/dyninst:/opt/rh/devtoolset-7/root/usr/lib64:/opt/rh/devtoolset-7/root/usr/lib"

# Install new DejaGNU for more reliable test summary generation
RUN mkdir -p /tmp/dejagnu && cd /tmp/dejagnu && \
    wget https://www.mirrorservice.org/sites/ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.2.tar.gz && \
    tar xf dejagnu-1.6.2.tar.gz && cd dejagnu-1.6.2 && \
    ./configure && make && make install && \
    cd /tmp && rm -rf dejagnu

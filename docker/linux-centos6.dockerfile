# Dockerfile for CentOS 6 toolchain builds
FROM centos:centos6

LABEL maintainer simon.cook@embecosm.com

RUN yum -y upgrade && yum -y groupinstall 'Development tools' && \
    yum -y install expect texinfo wget expat-devel

# Install newer toolchain components
RUN yum install -y centos-release-scl yum-utils && \
    yum-config-manager --enable rhel-server-rhscl-7-rpms && \
    yum install -y devtoolset-7 rh-python36

ENV PATH="/opt/rh/rh-python36/root/usr/bin:/opt/rh/devtoolset-7/root/usr/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/rh/rh-python36/root/usr/lib64:/opt/rh/devtoolset-7/root/usr/lib64:/opt/rh/devtoolset-7/root/usr/lib:/opt/rh/devtoolset-7/root/usr/lib64/dyninst:/opt/rh/devtoolset-7/root/usr/lib/dyninst:/opt/rh/devtoolset-7/root/usr/lib64:/opt/rh/devtoolset-7/root/usr/lib"

# Install new DejaGNU for more reliable test summary generation
RUN mkdir -p /tmp/dejagnu && cd /tmp/dejagnu && \
    wget https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.2.tar.gz && \
    tar xf dejagnu-1.6.2.tar.gz && cd dejagnu-1.6.2 && \
    ./configure && make && make install && \
    cd /tmp && rm -rf dejagnu

# Some tests require the user running testing to exist and have a home directory
# These values match what the Embecosm Buildbot builders are set up to use
RUN useradd -m -u 1002 builder

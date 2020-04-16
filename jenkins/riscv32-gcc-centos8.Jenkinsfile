// Default package version and bug URL
import java.time.*
import java.time.format.DateTimeFormatter
String CURRENTTIME = LocalDateTime.ofInstant(Instant.now(), ZoneOffset.UTC) \
                         .format(DateTimeFormatter.ofPattern("yyyyMMdd"))
String PKGVERS = "riscv32-embecosm-centos8-gcc-${CURRENTTIME}"
String BUGURL = 'https://www.embecosm.com'

// Bug URL and Package Version override parameters
properties([parameters([
    string(defaultValue: '', description: 'Package Version', name: 'PackageVersion'),
    string(defaultValue: '', description: 'Bug Reporting URL', name: 'BugURL'),
])])

if (params.PackageVersion != '')
  PKGVERS = params.PackageVersion
if (params.BugURL != '')
  BUGURL = params.BugURL
currentBuild.displayName = PKGVERS

node('builder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    dir('binutils-gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://sourceware.org/git/binutils-gdb.git']]])
    }
    dir('gcc') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/gcc-mirror/gcc.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'git://sourceware.org/git/newlib-cygwin.git']]])
    }
    dir('binutils-gdb-sim') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/cgen-sim-patch']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/embecosm/riscv-binutils-gdb.git']]])
    }
    sh script: './describe-build.sh'
    archiveArtifacts artifacts: 'build-sources.txt', fingerprint: true
  }

  stage('Prepare Docker') {
    image = docker.build('build-env-centos8',
                         '--no-cache -f docker/linux-centos8.dockerfile docker')
  }

  stage('Build') {
    image.inside {
      sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' ./build-riscv32-gcc.sh"
    }
  }

  stage('Package') {
    image.inside {
      sh script: "tar -czf ${PKGVERS}.tar.gz --transform s/^install/${PKGVERS}/ install"
      archiveArtifacts artifacts: "${PKGVERS}.tar.gz", fingerprint: true
    }
  }

  stage('Test') {
    // Build the CGEN simulator and use it for testing
    image.inside {
      dir('build/binutils-sim-32') {
            sh script: '''${WORKSPACE}/binutils-gdb-sim/configure \
                          --target=riscv32-unknown-elf             \
                          --prefix=${WORKSPACE}/install            \
                          --disable-gdb                            \
                          --enable-sim                             \
                          --disable-werror'''
            sh script: 'make -j$(nproc) all-sim'
            sh script: 'make install-sim'
      }
      dir('build/binutils-sim-64') {
            sh script: '''${WORKSPACE}/binutils-gdb-sim/configure \
                          --target=riscv64-unknown-elf             \
                          --prefix=${WORKSPACE}/install            \
                          --disable-gdb                            \
                          --enable-sim                             \
                          --disable-werror'''
            sh script: 'make -j$(nproc) all-sim'
            sh script: 'make install-sim'
      }
      sh script: 'cp utils/riscv-unknown-elf-run install/bin'
      dir('build/gcc-stage2') {
        sh script: '''export PATH=${WORKSPACE}/install/bin:${PATH}
                      export USER=builder
                      export RISCV_SIM_COMMAND=riscv-unknown-elf-run
                      export RISCV_TRIPLE=riscv32-unknown-elf
                      export DEJAGNU=${WORKSPACE}/dejagnu/riscv-sim-site.exp
                      # Calculate target list from multilib spec
                      TARGET_BOARD=riscv-sim
                      TARGET_BOARD="$(riscv32-unknown-elf-gcc -print-multi-lib | \
                                        sed -e 's/.*;//' \
                                            -e 's#@#/-#g' \
                                            -e 's/^/riscv-sim/' | awk 1 ORS=' ')"
                      make -j$(nproc) check-gcc \
                        RUNTESTFLAGS="--target_board='${TARGET_BOARD}'"
                      exit 0'''
        archiveArtifacts artifacts: '''gcc/testsuite/gcc/gcc.log,
                                       gcc/testsuite/gcc/gcc.sum,
                                       gcc/testsuite/g++/g++.log,
                                       gcc/testsuite/g++/g++.sum''',
                         fingerprint: true
      }
    }
  }
}

// Bug URL and Package Version parameters
properties([parameters([
    string(defaultValue: '', description: 'Package Version', name: 'PackageVersion'),
    string(defaultValue: '', description: 'Bug Reporting URL', name: 'BugURL'),
    string(defaultvalue: '', description: 'Binutils Tag', name: 'BinutilsTag'),
    string(defaultvalue: '', description: 'GDB Tag', name: 'GdbTag'),
    string(defaultvalue: '', description: 'GCC Tag', name: 'GccTag'),
    string(defaultvalue: '', description: 'Newlib Tag', name: 'NewlibTag'),
    booleanParam(defaultValue: false, description: 'Test with a reduced set of multilibs', name: 'ReducedMultilibTesting'),
])])

PKGVERS = params.PackageVersion
BUGURL = params.BugURL
if (PKGVERS != '')
  currentBuild.displayName = PKGVERS

node('builder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    dir('binutils') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${BinutilsTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://sourceware.org/git/binutils-gdb.git']]])
    }
    dir('gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${GdbTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://sourceware.org/git/binutils-gdb.git']]])
    }
    dir('gcc') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${GccTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/gcc-mirror/gcc.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${NewlibTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'git://sourceware.org/git/newlib-cygwin.git']]])
    }
    dir('binutils-gdb-sim') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/spc-cgen-sim-rve']],
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
      // Enable greater set of multilibs
      sh script: 'cd gcc/gcc/config/riscv && python3 ./multilib-generator rv32e-ilp32e--c rv32ea-ilp32e--m rv32em-ilp32e--c rv32eac-ilp32e-- rv32emac-ilp32e-- rv32i-ilp32--c rv32ia-ilp32--m rv32im-ilp32--c rv32if-ilp32f-rv32ifd-c rv32iaf-ilp32f-rv32imaf,rv32iafc-d rv32imf-ilp32f-rv32imfd-c rv32iac-ilp32-- rv32imac-ilp32-- rv32imafc-ilp32f-rv32imafdc- rv32ifd-ilp32d--c rv32imfd-ilp32d--c rv32iafd-ilp32d-rv32imafd,rv32iafdc- rv32imafdc-ilp32d-- rv64i-lp64--c rv64ia-lp64--m rv64im-lp64--c rv64if-lp64f-rv64ifd-c rv64iaf-lp64f-rv64imaf,rv64iafc-d rv64imf-lp64f-rv64imfd-c rv64iac-lp64-- rv64imac-lp64-- rv64imafc-lp64f-rv64imafdc- rv64ifd-lp64d--m,c rv64iafd-lp64d-rv64imafd,rv64iafdc- rv64imafdc-lp64d-- > t-elf-multilib'
      sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' ./stages/build-riscv32-gcc.sh"
    }
  }

  stage('Package') {
    image.inside {
      sh script: "tar -czf ${PKGVERS}.tar.gz --transform s/^install/${PKGVERS}/ install"
      archiveArtifacts artifacts: "${PKGVERS}.tar.gz", fingerprint: true
    }
  }

  stage('Test') {
    image.inside {
      if (params.ReducedMultilibTesting)
        sh script: '''REDUCED_MULTILIB_TEST=1 ./stages/test-riscv32-gcc.sh'''
      else
        sh script: '''./stages/test-riscv32-gcc.sh'''
      dir('build/gcc-stage2') {
        archiveArtifacts artifacts: '''gcc/testsuite/gcc/gcc.log,
                                       gcc/testsuite/gcc/gcc.sum,
                                       gcc/testsuite/g++/g++.log,
                                       gcc/testsuite/g++/g++.sum''',
                         fingerprint: true
      }
    }
  }
}

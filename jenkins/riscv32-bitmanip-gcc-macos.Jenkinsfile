// Default package version and bug URL
import java.time.*
import java.time.format.DateTimeFormatter
String CURRENTTIME = LocalDateTime.ofInstant(Instant.now(), ZoneOffset.UTC) \
                         .format(DateTimeFormatter.ofPattern("yyyyMMdd"))
String PKGVERS = "riscv32-experimental-bitmanip-gcc-macos-${CURRENTTIME}"
String BUGURL = 'https://www.embecosm.com'

// Bug URL and Package Version override parameters
properties([parameters([
    string(defaultValue: '', description: 'Package Version', name: 'PackageVersion'),
    string(defaultValue: '', description: 'Bug Reporting URL', name: 'BugURL'),
    booleanParam(defaultValue: false, description: 'Test with a reduced set of multilibs', name: 'ReducedMultilibTesting'),
])])

if (params.PackageVersion != '')
  PKGVERS = params.PackageVersion
if (params.BugURL != '')
  BUGURL = params.BugURL
currentBuild.displayName = PKGVERS

node('macbuilder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    dir('binutils-gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/embecosm-riscv-bitmanip']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/embecosm/riscv-binutils-gdb.git']]])
    }
    dir('gcc') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/riscv-bitmanip']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/embecosm/riscv-gcc.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/newlib-cygwin.git']]])
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

  stage('Build') {
    // Enable greater set of multilibs
    sh script: 'cd gcc/gcc/config/riscv && python3 ./multilib-generator rv32e-ilp32e--c rv32ea-ilp32e--m rv32em-ilp32e--c rv32eac-ilp32e-- rv32emac-ilp32e-- rv32i-ilp32--c rv32ia-ilp32--m rv32im-ilp32--c rv32if-ilp32f-rv32ifd-c rv32iaf-ilp32f-rv32imaf,rv32iafc-d rv32imf-ilp32f-rv32imfd-c rv32iac-ilp32-- rv32imac-ilp32-- rv32imafc-ilp32f-rv32imafdc- rv32ifd-ilp32d--c rv32imfd-ilp32d--c rv32iafd-ilp32d-rv32imafd,rv32iafdc- rv32imafdc-ilp32d-- rv64i-lp64--c rv64ia-lp64--m rv64im-lp64--c rv64if-lp64f-rv64ifd-c rv64iaf-lp64f-rv64imaf,rv64iafc-d rv64imf-lp64f-rv64imfd-c rv64iac-lp64-- rv64imac-lp64-- rv64imafc-lp64f-rv64imafdc- rv64ifd-lp64d--m,c rv64iafd-lp64d-rv64imafd,rv64iafdc- rv64imafdc-lp64d-- rv32eb-ilp32e--c rv32eab-ilp32e--m rv32emb-ilp32e--c rv32eacb-ilp32e-- rv32emacb-ilp32e-- rv32ib-ilp32--c rv32iab-ilp32--m rv32imb-ilp32--c rv32ifb-ilp32f-rv32ifdb-c rv32iafb-ilp32f-rv32imaf,rv32iafcb-d rv32imfb-ilp32f-rv32imfdb-c rv32iacb-ilp32-- rv32imacb-ilp32-- rv32imafcb-ilp32f-rv32imafdcb- rv32ifdb-ilp32d--c rv32imfdb-ilp32d--c rv32iafdb-ilp32d-rv32imafd,rv32iafdcb- rv32imafdcb-ilp32d-- rv64ib-lp64--c rv64iab-lp64--m rv64imb-lp64--c rv64ifb-lp64f-rv64ifdb-c rv64iafb-lp64f-rv64imaf,rv64iafcb-d rv64imfb-lp64f-rv64imfdb-c rv64iacb-lp64-- rv64imacb-lp64-- rv64imafcb-lp64f-rv64imafdcb- rv64ifdb-lp64d--m,c rv64iafdb-lp64d-rv64imafd,rv64iafdcb- rv64imafdcb-lp64d-- > t-elf-multilib'
    sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' PARALLEL_JOBS=2 ./stages/build-riscv32-gcc.sh"
  }

  stage('Package') {
    sh script: "gtar -czf ${PKGVERS}.tar.gz --transform s/^install/${PKGVERS}/ install"
    archiveArtifacts artifacts: "${PKGVERS}.tar.gz", fingerprint: true
  }

  stage('Test') {
    if (params.ReducedMultilibTesting)
      sh script: '''REDUCED_MULTILIB_TEST=1 PARALLEL_JOBS=2 ./stages/test-riscv32-gcc.sh'''
    else
      sh script: '''PARALLEL_JOBS=2 ./stages/test-riscv32-gcc.sh'''
    dir('build/gcc-stage2') {
      archiveArtifacts artifacts: '''gcc/testsuite/gcc/gcc.log,
                                     gcc/testsuite/gcc/gcc.sum,
                                     gcc/testsuite/g++/g++.log,
                                     gcc/testsuite/g++/g++.sum''',
                       fingerprint: true
    }
  }
}

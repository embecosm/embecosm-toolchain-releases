// Default package version and bug URL
import java.time.*
import java.time.format.DateTimeFormatter
String CURRENTTIME = LocalDateTime.ofInstant(Instant.now(), ZoneOffset.UTC) \
                         .format(DateTimeFormatter.ofPattern("yyyyMMdd"))
String PKGVERS = "corev-openhw-gcc-ubuntu1804-${CURRENTTIME}"
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

node('builder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    dir('binutils-gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/development']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/openhwgroup/corev-binutils-gdb.git']]])
    }
    dir('gcc') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/development']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          // Placeholder repo URL until https://github.com/openhwgroup/corev-gcc.git is populated
          userRemoteConfigs: [[url: 'https://github.com/simonpcook/corev-gcc.git']]])
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

  stage('Prepare Docker') {
    image = docker.build('build-env-ubuntu1804',
                         '--no-cache -f docker/linux-ubuntu1804.dockerfile docker')
  }

  stage('Build') {
    image.inside {
      sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' TRIPLE='riscv32-corev-elf' ./stages/build-riscv32-gcc.sh"
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
        sh script: '''REDUCED_MULTILIB_TEST=1 TRIPLE='riscv32-corev-elf' ./stages/test-riscv32-gcc.sh'''
      else
        sh script: '''TRIPLE='riscv32-corev-elf' ./stages/test-riscv32-gcc.sh'''
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

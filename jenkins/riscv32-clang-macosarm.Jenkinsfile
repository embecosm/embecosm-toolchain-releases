// NOTE: This file should be the same as the -macos version, except with a
// change in the node specifier and the target architecture

// Default package version and bug URL
import java.time.*
import java.time.format.DateTimeFormatter
String CURRENTTIME = LocalDateTime.ofInstant(Instant.now(), ZoneOffset.UTC) \
                         .format(DateTimeFormatter.ofPattern("yyyyMMdd"))
String PKGVERS = "riscv32-embecosm-clang-macos-${CURRENTTIME}"
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

node('armmacbuilder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    dir('binutils-gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/binutils-gdb.git']]])
    }
    dir('llvm-project') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/llvm-project.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/newlib-cygwin.git']]])
    }
    sh script: './describe-build.sh'
    archiveArtifacts artifacts: 'build-sources.txt', fingerprint: true
  }

  stage('Build') {
    sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' arch -arm64 ./stages/build-riscv32-clang.sh"
  }

  stage('Package') {
    sh script: "arch -arm64 utils/macos-code-sign-build.sh"
    sh script: "arch -arm64 utils/prepare-zip-package.sh ${PKGVERS}"
    sh script: "arch -arm64 tar -czf ${PKGVERS}.tar.gz ${PKGVERS}"
    sh script: "mkdir bundle-tmp && mv ${PKGVERS} bundle-tmp && hdiutil create -volname ${PKGVERS} -srcfolder bundle-tmp -ov -format UDZO ${PKGVERS}.dmg"
    sh script: "arch -arm64 utils/macos-notarize.sh '${PKGVERS}.zip' com.embecosm.toolchain.riscv32-clang"
    sh script: "arch -arm64 utils/macos-notarize.sh '${PKGVERS}.dmg' com.embecosm.toolchain.riscv32-clang"
    archiveArtifacts artifacts: "${PKGVERS}.zip, ${PKGVERS}.dmg, ${PKGVERS}.tar.gz", fingerprint: true
  }

  stage('Test') {
    dir('build/binutils-gdb') {
      sh script: 'arch -arm64 make check-gas', returnStatus: true
      sh script: 'arch -arm64 make check-ld', returnStatus: true
      sh script: 'arch -arm64 make check-binutils', returnStatus: true
      archiveArtifacts artifacts: '''gas/testsuite/gas.log,
                                     gas/testsuite/gas.sum,
                                     ld/ld.log,
                                     ld/ld.sum,
                                     binutils/binutils.log,
                                     binutils/binutils.sum''',
                        fingerprint: true
    }
    sh script: '''arch -arm64 ./stages/test-llvm.sh'''
    dir('build/llvm') {
      archiveArtifacts artifacts: 'llvm-tests.log', fingerprint: true
    }
  }
}

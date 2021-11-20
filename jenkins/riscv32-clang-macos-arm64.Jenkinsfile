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

node('macarmbuilder') {
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
          branches: [[name: '*/main']],
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
    sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' EXTRA_BINUTILS_OPTS='--enable-libctf=no' ./stages/build-riscv32-clang.sh"
  }

  stage('Package') {
    sh script: "utils/macos-code-sign-build.sh"
    sh script: "utils/prepare-zip-package.sh ${PKGVERS}"
    sh script: "mkdir bundle-tmp && mv ${PKGVERS} bundle-tmp && hdiutil create -volname ${PKGVERS} -srcfolder bundle-tmp -ov -format UDZO ${PKGVERS}.dmg"
    sh script: "utils/macos-notarize.sh '${PKGVERS}.zip' com.embecosm.toolchain.riscv32-clang"
    sh script: "utils/macos-notarize.sh '${PKGVERS}.dmg' com.embecosm.toolchain.riscv32-clang"
  }

  stage('Test') {
    dir('build/binutils-gdb') {
      sh script: 'make check-gas', returnStatus: true
      sh script: 'make check-ld', returnStatus: true
      sh script: 'make check-binutils', returnStatus: true
      archiveArtifacts artifacts: '''gas/testsuite/gas.log,
                                     gas/testsuite/gas.sum,
                                     ld/ld.log,
                                     ld/ld.sum,
                                     binutils/binutils.log,
                                     binutils/binutils.sum''',
                        fingerprint: true
    }
    sh script: '''./stages/test-llvm.sh'''
    dir('build/llvm') {
      archiveArtifacts artifacts: 'llvm-tests.log', fingerprint: true
    }
  }

  stage('Notarize') {
    sh script: "xcrun stapler staple ${PKGVERS}.dmg"
    archiveArtifacts artifacts: "${PKGVERS}.zip, ${PKGVERS}.dmg", fingerprint: true
  }
}

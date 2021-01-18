// Default package version and bug URL
import java.time.*
import java.time.format.DateTimeFormatter
String CURRENTTIME = LocalDateTime.ofInstant(Instant.now(), ZoneOffset.UTC) \
                         .format(DateTimeFormatter.ofPattern("yyyyMMdd"))
String PKGVERS = "or1k-embecosm-gcc-macos-${CURRENTTIME}"
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

node('macbuilder') {
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
    dir('gcc') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/gcc.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/newlib-cygwin.git']]])
    }
    // or1k-utils is used for the site file
    dir('or1k-utils') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/stffrdhrn/or1k-utils.git']]])
    }
    sh script: './describe-build.sh'
    archiveArtifacts artifacts: 'build-sources.txt', fingerprint: true
  }

  stage('Build') {
    sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' EXTRA_BINUTILS_OPTS='--enable-libctf=no' ./stages/build-or1k-gcc.sh"
  }

  stage('Package') {
    sh script: "utils/macos-code-sign-build.sh"
    sh script: "utils/prepare-zip-package.sh ${PKGVERS}"
    sh script: "mkdir bundle-tmp && mv ${PKGVERS} bundle-tmp && hdiutil create -volname ${PKGVERS} -srcfolder bundle-tmp -ov -format UDZO ${PKGVERS}.dmg"
    sh script: "utils/macos-notarize.sh '${PKGVERS}.zip' com.embecosm.toolchain.or1k-gcc"
    sh script: "utils/macos-notarize.sh '${PKGVERS}.dmg' com.embecosm.toolchain.or1k-gcc"
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
    sh script: '''./stages/test-or1k-gcc.sh'''
    dir('build/gcc-stage2') {
      archiveArtifacts artifacts: '''gcc/testsuite/gcc/gcc.log,
                                     gcc/testsuite/gcc/gcc.sum,
                                     gcc/testsuite/g++/g++.log,
                                     gcc/testsuite/g++/g++.sum''',
                       fingerprint: true
    }
  }

  stage('Notarize') {
    sh script: "xcrun stapler staple ${PKGVERS}.dmg"
    archiveArtifacts artifacts: "${PKGVERS}.zip, ${PKGVERS}.dmg", fingerprint: true
  }
}

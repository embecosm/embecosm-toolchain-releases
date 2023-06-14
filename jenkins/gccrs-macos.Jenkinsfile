// Default package version and bug URL
import java.time.*
import java.time.format.DateTimeFormatter
String CURRENTTIME = LocalDateTime.ofInstant(Instant.now(), ZoneOffset.UTC) \
                         .format(DateTimeFormatter.ofPattern("yyyyMMdd"))
String PKGVERS = "gccrs-macos-${CURRENTTIME}"
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
    dir('gccrs') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/master']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/gccrs.git']]])
    }
    sh script: './describe-build.sh'
    archiveArtifacts artifacts: 'build-sources.txt', fingerprint: true
  }

  stage('Build') {
    sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' EXTRA_GCC_OPTS='--with-sysroot=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk' ./stages/build-gccrs.sh"
  }

  stage('Package') {
    sh script: "utils/macos-code-sign-build.sh"
    sh script: "utils/prepare-zip-package.sh ${PKGVERS}"
    sh script: "mkdir bundle-tmp && mv ${PKGVERS} bundle-tmp && hdiutil create -volname ${PKGVERS} -srcfolder bundle-tmp -ov -format UDZO ${PKGVERS}.dmg"
    sh script: "utils/macos-notarize.sh '${PKGVERS}.zip'"
    sh script: "utils/macos-notarize.sh '${PKGVERS}.dmg'"
    archiveArtifacts artifacts: "${PKGVERS}.zip, ${PKGVERS}.dmg", fingerprint: true
  }

  stage('Test') {
    sh script: '''./stages/test-gccrs.sh'''
    dir('build/gccrs') {
      archiveArtifacts artifacts: '''gcc/testsuite/rust/rust.log,
                                     gcc/testsuite/rust/rust.sum''',
                        fingerprint: true
    }
  }
}

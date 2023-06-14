// Bug URL and Package Version parameters
properties([parameters([
    string(defaultValue: '', description: 'Package Version', name: 'PackageVersion'),
    string(defaultValue: '', description: 'Bug Reporting URL', name: 'BugURL'),
    string(defaultvalue: '', description: 'GCC Tag', name: 'GccTag'),
])])

PKGVERS = params.PackageVersion
BUGURL = params.BugURL
if (PKGVERS != '')
  currentBuild.displayName = PKGVERS

node('macarmbuilder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    dir('gccrs') {
      checkout([$class: 'GitSCM',
          branches: [[name: "${GccTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/Rust-GCC/gccrs.git']]])
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

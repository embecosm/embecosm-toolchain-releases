// Bug URL and Package Version parameters
properties([parameters([
    string(defaultValue: '', description: 'Package Version', name: 'PackageVersion'),
    string(defaultValue: '', description: 'Bug Reporting URL', name: 'BugURL'),
    string(defaultvalue: '', description: 'Binutils Tag', name: 'BinutilsTag'),
    string(defaultvalue: '', description: 'GDB Tag', name: 'GdbTag'),
    string(defaultvalue: '', description: 'GCC Tag', name: 'GccTag'),
    string(defaultvalue: '', description: 'Newlib Tag', name: 'NewlibTag'),
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
    dir('binutils') {
      checkout([$class: 'GitSCM',
          branches: [[name: 'tags/${BinutilsTag}']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://sourceware.org/git/binutils-gdb.git']]])
    }
    dir('gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: 'tags/${GdbTag}']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://sourceware.org/git/binutils-gdb.git']]])
    }
    dir('gcc') {
      checkout([$class: 'GitSCM',
          branches: [[name: 'tags/${GccTag}']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/gcc-mirror/gcc.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: 'tags/${NewlibTag}']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'git://sourceware.org/git/newlib-cygwin.git']]])
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
    sh script: "utils/macos-notarize.sh '${PKGVERS}.zip'"
    sh script: "utils/macos-notarize.sh '${PKGVERS}.dmg'"
    archiveArtifacts artifacts: "${PKGVERS}.zip, ${PKGVERS}.dmg", fingerprint: true
  }

  stage('Test') {
    dir('build/binutils') {
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
}

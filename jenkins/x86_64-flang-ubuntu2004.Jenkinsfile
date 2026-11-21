// Bug URL and Package Version parameters
properties([parameters([
    string(defaultValue: '', description: 'Package Version', name: 'PackageVersion'),
    string(defaultValue: '', description: 'Bug Reporting URL', name: 'BugURL'),
    string(defaultvalue: '', description: 'LLVM Tag', name: 'LLVMTag'),
    string(defaultvalue: '', description: 'Newlib Tag', name: 'NewlibTag'),
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
    dir('llvm-project') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${LLVMTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/llvm/llvm-project.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${NewlibTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'git://sourceware.org/git/newlib-cygwin.git']]])
    }
    sh script: './describe-build.sh'
    archiveArtifacts artifacts: 'build-sources.txt', fingerprint: true
  }

  stage('Prepare Docker') {
    image = docker.build('build-env-ubuntu2004',
                         '--no-cache -f docker/linux-ubuntu2004.dockerfile docker')
  }

  stage('Build') {
    image.inside {
      sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' ./stages/build-x86_64-flang.sh"
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
      sh script: '''./stages/test-llvm.sh'''
      dir('build/llvm') {
        archiveArtifacts artifacts: 'llvm-tests.log', fingerprint: true
      }
    }
  }
}

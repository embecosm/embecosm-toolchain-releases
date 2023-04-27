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

node('builder') {
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

  stage('Prepare Docker') {
    image = docker.build('build-env-rocky9',
                         '--no-cache -f docker/linux-rocky9.dockerfile docker')
  }

  stage('Build') {
    image.inside {
      sh script: "BUGURL='${BUGURL}' PKGVERS='${PKGVERS}' ./stages/build-gccrs.sh"
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
      sh script: '''./stages/test-gccrs.sh'''
      dir('build/gccrs') {
        archiveArtifacts artifacts: '''gcc/testsuite/rust/rust.log,
                                       gcc/testsuite/rust/rust.sum''',
                         fingerprint: true
      }
    }
  }
}

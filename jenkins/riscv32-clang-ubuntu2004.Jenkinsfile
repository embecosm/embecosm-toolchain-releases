// Thing to build
properties([parameters([
    string(defaultValue: '', description: 'RefSpec', name: 'RefSpec'),
])])

if (params.RefSpec != '')
  currentBuild.displayName = params.RefSpec

node('builder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    dir('binutils-gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: 'tags/gdb-10.1-release']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/binutils-gdb.git']]])
    }
    dir('llvm-project') {
      checkout([$class: 'GitSCM',
          branches: [[name: 'tags/llvmorg-12.0.0']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/llvm-project.git']]])
    }
    dir('newlib') {
      checkout([$class: 'GitSCM',
          branches: [[name: 'tags/newlib-4.1.0']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://mirrors.git.embecosm.com/mirrors/newlib-cygwin.git']]])
    }
    dir('gcc-for-llvm-testing') {
      checkout([$class: 'GitSCM',
          branches: [[name: '${RefSpec}']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[refspec: '+refs/pull/*:refs/remotes/origin/pr/*', url: 'https://github.com/embecosm/gcc-for-llvm-testing.git']]])
    }
    dir('binutils-gdb-sim') {
      checkout([$class: 'GitSCM',
          branches: [[name: '*/spc-cgen-sim-rve']],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://github.com/embecosm/riscv-binutils-gdb.git']]])
    }
  }

  stage('Prepare Docker') {
    image = docker.build('build-env-ubuntu2004',
                         '--no-cache -f jenkins/linux-ubuntu2004.dockerfile jenkins')
  }

  stage('Build Clang') {
    image.inside {
      sh script: "./build-riscv32-clang.sh"
    }
  }

  stage('Test Clang') {
    image.inside {
      sh script: './run-tests.py', returnStatus: true
      archiveArtifacts artifacts: 'test-output/gcc.log, test-output/gcc.sum', fingerprint: true
    }
  }

  stage('Build GCC') {
    image.inside {
      sh script: "./build-riscv32-gcc.sh"
    }
  }

  stage('Test GCC') {
    image.inside {
      sh script: './test-riscv32-gcc.sh', returnStatus: true
      archiveArtifacts artifacts: 'build-gcc/gcc-stage2/gcc/testsuite/gcc/gcc.log, build-gcc/gcc-stage2/gcc/testsuite/gcc/gcc.sum, build-gcc/gcc-stage2/gcc/testsuite/g++/g++.log, build-gcc/gcc-stage2/gcc/testsuite/g++/g++.sum', fingerprint: true
    }
  }
}

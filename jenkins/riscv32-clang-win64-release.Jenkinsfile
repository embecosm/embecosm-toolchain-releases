// This directory is where to expect a MSYS64 installation on the build node
String MSYSHOME = 'C:\\msys64j'

// Bug URL and Package Version parameters
properties([parameters([
    string(defaultValue: '', description: 'Package Version', name: 'PackageVersion'),
    string(defaultValue: '', description: 'Bug Reporting URL', name: 'BugURL'),
    string(defaultvalue: '', description: 'Binutils Tag', name: 'BinutilsTag'),
    string(defaultvalue: '', description: 'GDB Tag', name: 'GdbTag'),
    string(defaultvalue: '', description: 'LLVM Tag', name: 'LLVMTag'),
    string(defaultvalue: '', description: 'Newlib Tag', name: 'NewlibTag'),
])])

PKGVERS = params.PackageVersion
BUGURL = params.BugURL
if (PKGVERS != '')
  currentBuild.displayName = PKGVERS

node('winbuilder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    // Store workspace dir in a file we can source later
    bat script: """${MSYSHOME}\\usr\\bin\\cygpath %WORKSPACE% > workspacedir"""

    dir('binutils') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${BinutilsTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://sourceware.org/git/binutils-gdb.git']]])
    }
    dir('gdb') {
      checkout([$class: 'GitSCM',
          branches: [[name: "tags/${GdbTag}"]],
          extensions: [[$class: 'CloneOption', shallow: true]],
          userRemoteConfigs: [[url: 'https://sourceware.org/git/binutils-gdb.git']]])
    }
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
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE% && ./describe-build.sh" """
    archiveArtifacts artifacts: 'build-sources.txt', fingerprint: true
  }

  stage('Build') {
    bat script: """set MSYSTEM=MINGW64
                   set BUGURL=${BUGURL}
                   set PKGVERS=${PKGVERS}
                   set EXTRA_BINUTILS_OPTS=--with-python=no --with-system-readline --disable-sim
                   set EXTRA_LLVM_OPTS=-DLLVM_ENABLE_THREADS=OFF
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE% && ./stages/build-riscv32-clang.sh" """
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE% && ./utils/extract-mingw-dlls.sh" """
  }

  stage('Package') {
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE% && utils/prepare-zip-package.sh ${PKGVERS}" """
    archiveArtifacts artifacts: "${PKGVERS}.zip", fingerprint: true
  }

  stage('Test') {
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE%/build/binutils && make check-gas" """, returnStatus: true
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE%/build/binutils && make check-ld" """, returnStatus: true
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE%/build/binutils && make check-binutils" """, returnStatus: true
    dir('build/binutils') {
      archiveArtifacts artifacts: '''gas/testsuite/gas.log,
                                     gas/testsuite/gas.sum,
                                     ld/ld.log,
                                     ld/ld.sum,
                                     binutils/binutils.log,
                                     binutils/binutils.sum''',
                       fingerprint: true
    }
    // Build the CGEN simulator and use it for testing
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE% && ./stages/test-llvm.sh" """
    dir('build/llvm') {
      archiveArtifacts artifacts: 'llvm-tests.log', fingerprint: true
    }
  }
}

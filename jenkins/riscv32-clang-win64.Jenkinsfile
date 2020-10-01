// Default package version and bug URL
import java.time.*
import java.time.format.DateTimeFormatter
String CURRENTTIME = LocalDateTime.ofInstant(Instant.now(), ZoneOffset.UTC) \
                         .format(DateTimeFormatter.ofPattern("yyyyMMdd"))
String PKGVERS = "riscv32-embecosm-clang-win64-${CURRENTTIME}"
String BUGURL = 'https://www.embecosm.com'

// This directory is where to expect a MSYS64 installation on the build node
String MSYSHOME = 'C:\\msys64j'

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

node('winbuilder') {
  stage('Cleanup') {
    deleteDir()
  }

  stage('Checkout') {
    checkout scm
    // Store workspace dir in a file we can source later
    bat script: """${MSYSHOME}\\usr\\bin\\cygpath %WORKSPACE% > workspacedir"""

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
                   set EXTRA_BINUTILS_OPTS=--with-python=no --with-system-readline
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
                       "cd %UNIXWORKSPACE%\\build\\binutils-gdb && make check-gas" """, returnStatus: true
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE%\\build\\binutils-gdb && make check-ld" """, returnStatus: true
    bat script: """set MSYSTEM=MINGW64
                   set /P UNIXWORKSPACE=<workspacedir
                   ${MSYSHOME}\\usr\\bin\\bash --login -c ^
                       "cd %UNIXWORKSPACE%\\build\\binutils-gdb && make check-binutils" """, returnStatus: true
    dir('build/binutils-gdb') {
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

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

// Get base name of job for invoking child jobs
String JobPrefix = env.JOB_NAME.replace('-universal','')
String IntelJob = "${JobPrefix}-intel"
String ArmJob = "${JobPrefix}-arm"

// Build Intel and ARM versions of the tool
parallel 'Intel Build': {
    stage('Intel Build') {
        intel = build job: "${IntelJob}",
                      parameters: [stringParam(name: 'PackageVersion', value: PKGVERS),
                                   stringParam(name: 'BugURL', value: BUGURL)]
    }
}, 'ARM Build': {
    stage('ARM Build') {
        arm = build job: "${ArmJob}",
                    parameters: [stringParam(name: 'PackageVersion', value: PKGVERS),
                                 stringParam(name: 'BugURL', value: BUGURL)]
    }
}

// Download and merge packages
node('macbuilder') {
    stage('Combine') {
        deleteDir()
        copyArtifacts filter: "${PKGVERS}.zip", projectName: "${IntelJob}", selector: specific("$intel.number"), target: 'intel'
        copyArtifacts filter: "${PKGVERS}.zip", projectName: "${ArmJob}", selector: specific("$arm.number"), target: 'arm'
    }
}

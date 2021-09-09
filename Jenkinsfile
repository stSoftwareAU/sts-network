/*
 * WARNING: Automatically copied from dga-tools.
 */
pipeline {
  agent none
  triggers {
    pollSCM( '* 22,23,0-8 * * 0-5')
    cron( 'H H(2-3) * * H(2-4)') // UTC About Midday Sydney time on a workday.
  }

  options {
    timeout(time: 1, unit: 'HOURS')
    disableConcurrentBuilds()
    parallelsAlwaysFailFast()
  }

  stages {
    stage('Build') {
      agent {
        docker {
          image 'dga-tools:latest'
          args '--volume /var/run/docker.sock:/var/run/docker.sock --volume /tmp:/tmp'
        }
      }

      steps {
        script {
          /**
           * Keep the COMMIT at the start of the build process so that it doesn't change during the build.
           */
          env.COMMIT_ID = env.GIT_COMMIT
        }

        sh '''\
          #!/bin/bash
          set -ex

          /home/tools/build.sh
          /home/tools/push.sh
        '''.stripIndent()
      }
    }

    stage('QA') {
      parallel {
        stage('validate') {
          agent {
            docker {
                image 'dga-tools:latest'
                args '--volume /var/run/docker.sock:/var/run/docker.sock --volume /tmp:/tmp'
            }
          }

          steps {
            sh '''\
              #!/bin/bash
              set -ex

              /home/tools/pull.sh
              /home/tools/run.sh --require 3.2 --mode validate
            '''.stripIndent()
          }
        }

        stage('CVE scan') {
          when { anyOf { branch 'Develop'; changeRequest target: 'Develop' } }
          agent {
            docker {
              image 'dga-tools:latest'
              args '--volume /var/run/docker.sock:/var/run/docker.sock'
            }
          }

          steps {
            script {
              try {
                sh '''\
                  #!/bin/bash
                  set -ex

                  /home/tools/cve-scan.sh
                '''.stripIndent()
                env.CVE_SCAN_FAILED = false
              }
              catch (err) {
                echo "Caught: ${err}"
                env.CVE_SCAN_FAILED = true
              }
            }
          }
          post {
            always {
              archiveArtifacts artifacts: 'cve-scan.json', fingerprint: true
            }
          }
        }
      }
    }

    stage('Prompt') {
      when { expression { env.CVE_SCAN_FAILED == 'true' } }
      steps {
        script {
          try {
            timeout(time: 15, unit: 'MINUTES') {
              input( message: 'CVE scan detected issues', ok: 'Continue?')
            }
          } catch (err) { // timeout reached or input false
            echo "Caught: ${err}"
            currentBuild.result = 'FAILURE'
          }
        }
      }
    }

    stage('Release') {
      agent {
        docker {
          image 'dga-tools:latest'
          args '--volume /var/run/docker.sock:/var/run/docker.sock'
        }
      }

      steps {
        sh '''\
          #!/bin/bash
          set -ex

          /home/tools/release.sh
        '''.stripIndent()
      }
    }
  }
}

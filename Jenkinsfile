/*
 * WARNING: Automatically copied from dga-tools
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
        docker{
          image 'dga-tools:latest'
          args '--volume /var/run/docker.sock:/var/run/docker.sock --volume /tmp:/tmp'
        }
      }

      steps {
        script{
          /**
           * Keep the COMMIT at the start of the build process so that it doesn't change during the build.
           */
          env.COMMIT_ID=env.GIT_COMMIT
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
            docker{
                image 'dga-tools:latest'
                args '--volume /var/run/docker.sock:/var/run/docker.sock --volume /tmp:/tmp'
            }
          }

          steps {
            sh '''\
              #!/bin/bash
              set -ex

              /home/tools/pull.sh
              /home/tools/run.sh --require 3.01 --mode validate
            '''.stripIndent()
          }
        }
        
        stage('CVE scan') {
          when { anyOf{ branch 'Develop'; changeRequest target: 'Develop'} }
          agent {
            docker{
              image 'dga-tools:latest'
              args '--volume /var/run/docker.sock:/var/run/docker.sock'
            }
          }

          steps {
            sh '''\
              #!/bin/bash
              set -ex
              
              /home/tools/cve-scan.sh
            '''.stripIndent()
          } 
          post {
            always {
              archiveArtifacts artifacts: 'cve-scan.json', fingerprint: true
            }    
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

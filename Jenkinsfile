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

                sh '''\
                    #!/bin/bash
                    set -e

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
                echo 'test..'
                sh '''\
                /home/tools/pull.sh
                /home/tools/run.sh --require 2.2 --mode validate
                '''
              }
            }
            stage('CVE scan') {
              agent {
                label 'ec2-large'
              }

              steps {
                echo 'scan..'

                sh '''\
                sleep 1
                '''
              }
            }
          }
        }

        stage('Release') {

            agent {
                docker{
                    image 'dga-tools:latest'
                    args '--volume /var/run/docker.sock:/var/run/docker.sock'
                }
            }

            steps {

                sh '''\
                    #!/bin/bash
                    set -e

                    /home/tools/release.sh
                '''.stripIndent()
            }
        }
    }
}

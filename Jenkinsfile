/*
 * WARNING: Automatically copied from dga-tools
 */
pipeline {
    agent none
    triggers {
        pollSCM( '* 0-8 * * 1-5')
        cron( 'H 3 * * 3') // UTC About Midday Sydney time
    }

    environment {
        GIT_CREDENTIALS = 'e0c8abc2-7a04-4a41-96b1-1d56c0cf1874'
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

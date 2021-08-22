pipeline {
    agent none
    triggers {
        pollSCM( '* 22,23,0-8 * * 0-5')
        cron( 'H H(2-3) * * H(2-4)') // UTC About Midday Sydney time on a workday.
    }

    options {
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
        // retry(3)
        parallelsAlwaysFailFast()
    }

    stages {
        stage('Build') {
            agent {
                label 'ec2-large'
            }

            steps {
                sh '''\
                #!/bin/bash
                set -e

                ./build.sh

                ./push.sh
                '''
            }
        }

        stage('QA') {
            parallel {
                stage('Selenium') {
                    agent {
                        label 'ec2-large'
                    }

                    steps {
                        echo 'test..'
                        sh '''\
                        sleep 1
                        '''
                    }
                }
                stage('CVE scan') {
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
                        
                        /home/tools/cve-scan.sh
                        '''.stripIndent()
                    } 
                    post {
                        always {
                            sh '''\
                            #!/bin/bash
                            set -e
                            ls
                            pwd
                            '''
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
                    set -e

                    /home/tools/release.sh
                '''.stripIndent()
            }
        }
    }   
}

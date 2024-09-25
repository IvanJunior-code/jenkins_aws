pipeline {
    agent any

    stages {
        stage ('Build Image') {
            steps {
                script {
                    dockerapp = docker.build("ivanjuniordocker/web-app:${env.BUILD_ID}", "-f ./src/Dockerfile ./src")
                }
            }
        }

        stage ('Push Image') {
            steps {
                script {
                    docker.withRegistry("https://registry.hub.docker.com", 'dockerhub') {
                        dockerapp.push('latest')
                        dockerapp.push("${env.BUILD_ID}")
                    }
                }
            }
        }

        stage ('Deploy no Kubernetes') {
            environment {
                tag_version = "${env.BUILD_ID}"
            }
            steps {
                // Configurar o AWS CLI
                withAWS(credentials: 'jenkins-credential', region: 'us-east-1') {

                    // Configurar o kubectl
                    sh 'aws eks update-kubeconfig --name eks'

                    // Configurar a imagem gerada no deployment.yaml
                    sh 'sed -i "s/{{tag}}/$tag_version/g" ./k8s/deployment.yaml'

                    // Aplicar o deploy
                    sh 'kubectl apply -f ./k8s/deployment.yaml'
                }
            }
        }
    }
}

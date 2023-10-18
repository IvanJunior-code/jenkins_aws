terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1" #Norte da Virgínia
}

# EC2 para executar o Jenkins
resource "aws_instance" "app_server" {
  ami           = "ami-06db4d78cb1d3bbf9" #https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LaunchInstances:
  instance_type = "t2.small"
  key_name = "iac-jenkins" #nome da chave (arquivo .pem)
  user_data = <<-EOF
                 #!/bin/bash

                 # Instalação do OpenJDK (Java)
                 sudo apt update && sudo apt install fontconfig openjdk-17-jre --yes

                 # Instalação do Jenkins
                 sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
                 https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
                 echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
                 https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
                 /etc/apt/sources.list.d/jenkins.list > /dev/null
                 sudo apt-get update
                 sudo apt-get install jenkins --yes

                 # Instalação do unzip
                 sudo apt-get install unzip --yes
 
                 # Instalação do AWS CLI
                 curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                 unzip awscliv2.zip
                 sudo ./aws/install
 
                 # Instalação do Docker
                 sudo curl -fsSL https://get.docker.com | bash
 
                 # Configurando permissão para o usuário jenkins poder utilizar o Docker
                 sudo usermod -aG docker jenkins
 
                 # Instalação do kubectl
                 sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
                 curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                 echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
                 sudo apt-get update && sudo apt-get install -y kubectl

                 # Reiniciando o Jenkins
                 sudo systemctl restart jenkins

                 # Instalando o busybox para teste
                 sudo apt-get install busybox --yes

                 # Salvando status o status do Jenkins em um index.html
                 sudo systemctl status jenkins | grep Active: | sed 's/Active://' | sed 's/.*/<h1>Jenkins status = &<\/h1>/' > /home/admin/index.html
                 
                 # Expondo o resultado do status do Jenkins na porta 8000
                 cd /home/admin
                 nohup busybox httpd -f -p 8000 &
                 EOF

  tags = {
    Name = "Instância Jenkins"
  }
}
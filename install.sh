#!/bin/bash

# Instalação do OpenJDK (Java)
sudo apt update && sudo apt install fontconfig openjdk-17-jre --yes

# Instalação do Jenkins
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update && sudo apt-get install jenkins --yes

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

# Exibindo o status do Jenkins
sudo systemctl status jenkins

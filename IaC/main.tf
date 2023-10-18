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
  
  tags = {
    Name = "Instância Jenkins"
  }
}
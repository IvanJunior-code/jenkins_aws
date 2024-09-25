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
  region = "us-east-1" #Norte da Virgínia
}

# EC2 para executar o Jenkins
resource "aws_instance" "jenkins_server" {
  ami           = "ami-06db4d78cb1d3bbf9" #https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LaunchInstances:
  instance_type = "t2.small"
  key_name      = "iac-jenkins" #nome da chave (arquivo .pem)
  user_data     = <<-EOF
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
                 curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                 curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
                 echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
                 sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

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

###########################################################
# VPC

resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"
  #instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC id."

  sensitive = false
}
#############################


###########################################################
# Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}
#############################


###########################################################
# Subnets

# public subnet 1
resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/18"

  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true # requisito do EKS, para as instâncias do cluster terem IP publico

  tags = {
    Name                        = "public-us-east-1a"
    "kubernetes.io/cluster/eks" = "shared" # Required to EKS
    "kubernetes.io/role/elb"    = 1        # Required to EKS
  }
}

# public subnet 2
resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.64.0/18"

  availability_zone = "us-east-1b"

  map_public_ip_on_launch = true

  tags = {
    Name                        = "public-us-east-1b"
    "kubernetes.io/cluster/eks" = "shared"
    "kubernetes.io/role/elb"    = 1
  }
}

# private subnet 1
resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.128.0/18"

  availability_zone = "us-east-1a"

  tags = {
    Name                              = "private-us-east-1a"
    "kubernetes.io/cluster/eks"       = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# private subnet 2
resource "aws_subnet" "private_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.192.0/18"

  availability_zone = "us-east-1b"

  tags = {
    Name                              = "private-us-east-1b"
    "kubernetes.io/cluster/eks"       = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}
#############################


###########################################################
# Elastic IP

resource "aws_eip" "nat1" {
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip" "nat2" {
  depends_on = [aws_internet_gateway.gw]
}
#############################


###########################################################
# NAT Gateway

resource "aws_nat_gateway" "gw1" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "NAT 1"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "gw2" {
  allocation_id = aws_eip.nat2.id
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name = "NAT 2"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}
#############################


###########################################################
# Route Tables

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw1.id
  }

  tags = {
    Name = "private1"
  }
}

resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw2.id
  }

  tags = {
    Name = "private2"
  }
}
#############################


###########################################################
# Route Tables Association

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private1.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private2.id
}
#############################


###########################################################
# Role
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

}
#############################


###########################################################
# Role Policy Attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSClusterPolicy.html
}
#############################


###########################################################
# EKS
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster

resource "aws_eks_cluster" "eks" {
  name     = "eks"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {

    endpoint_private_access = false
    endpoint_public_access  = true

    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_cluster_policy,
    #aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}
#############################


###########################################################
# Role to Node Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role

resource "aws_iam_role" "nodes_general" {
  name = "eks-node-group-general"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}
#############################


###########################################################
# Role Policies Attachment for Node Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy_general" {
  role       = aws_iam_role.nodes_general.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSWorkerNodePolicy.html
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy_general" {
  role       = aws_iam_role.nodes_general.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKS_CNI_Policy.html
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  role       = aws_iam_role.nodes_general.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEC2ContainerRegistryReadOnly.html
}
#############################


###########################################################
# EKS Node Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group#disk_size

resource "aws_eks_node_group" "nodes_general" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "nodes-general"
  node_role_arn   = aws_iam_role.nodes_general.arn

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  ami_type             = "AL2_x86_64"
  capacity_type        = "ON_DEMAND"
  disk_size            = 20
  force_update_version = false
  instance_types       = ["t3.small"]

  labels = {
    role = "nodes-general"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy_general,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy_general,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]
}
#############################

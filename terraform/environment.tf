provider "aws" {
  access_key = "AKIAVH6HC4RR5ER47H7N"
  secret_key = "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"
  region     = "eu-central-1"
}


# Creating VPC
resource "aws_vpc" "gw_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "gw_vpc"
  }
}

# Creating IGW
resource "aws_internet_gateway" "gw_igw" {
  vpc_id = aws_vpc.gw_vpc.id
  tags = {
    Name = "gw_igw"
  }
}

# Creating public subnet
resource "aws_subnet" "gw_public_subnet" {
  vpc_id                  = aws_vpc.gw_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "gw_public_subnet"
  }
}

# Creating private subnet
resource "aws_subnet" "gw_private_subnet" {
  vpc_id                  = aws_vpc.gw_vpc.id
  cidr_block              = "10.0.100.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "gw_private_subnet"
  }
}

# Route table public
resource "aws_route_table" "gw_public_rt" {
  vpc_id = aws_vpc.gw_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_igw.id
  }
  tags = {
    Name = "gw_public_rt"
  }
}

# Route table private
resource "aws_default_route_table" "gw_private_rt" {
  default_route_table_id = aws_vpc.gw_vpc.default_route_table_id
  tags = {
    Name = "gw_private_rt"
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.gw_public_subnet.id
  route_table_id = aws_route_table.gw_public_rt.id
}

# Route table association with private subnets
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.gw_private_subnet.id
  route_table_id = aws_default_route_table.gw_private_rt.id
}

### Creating security groups
# DevTools SG
resource "aws_security_group" "devtools_sg" {
  name        = "devtools_sg"
  description = "devtools_sg"
  vpc_id      = aws_vpc.gw_vpc.id


  dynamic "ingress" {
    for_each = ["22", "8080"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devtools_sg"
  }
}

# Artifactory SG
resource "aws_security_group" "artifactory_sg" {
  name        = "artifactory_sg"
  description = "artifactory_sg"
  vpc_id      = aws_vpc.gw_vpc.id


  dynamic "ingress" {
    for_each = ["22", "5000", "8081"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "artifactory_sg"
  }
}

# Destination SG
resource "aws_security_group" "destination_sg" {
  name        = "destination_sg"
  description = "destination_sg"
  vpc_id      = aws_vpc.gw_vpc.id


  dynamic "ingress" {
    for_each = ["22", "8888", "9999"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "destination_sg"
  }
}

# ICMP SG
resource "aws_security_group" "destination_sg" {
  name        = "icmp_sg"
  description = "icmp_sg"
  vpc_id      = aws_vpc.gw_vpc.id

  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "icmp_sg"
  }
}
 

### SERVERS configuration
# DevTools server
resource "aws_instance" "DevTools" {
  ami                    = "ami-0e342d72b12109f91"
  instance_type          = "t2.micro"
  key_name               = "aws_frankfurt_key"
  vpc_security_group_ids = [aws_security_group.devtools_sg.id, aws_security_group.icmp_sg.id]
  subnet_id = aws_subnet.gw_public_subnet.id
  private_ip = "10.0.1.10"

  tags = {
    Name = "DevTools"
  }
  #save instance_ip
  provisioner "local-exec" {
    command = "echo DevTools ${aws_instance.DevTools.public_ip} > ../public_ips.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "echo --------------INSTALLING JAVA-------------",
      "sudo apt-get update",
      "sudo apt-get install --yes openjdk-8-jre",
      "sudo apt-get install --yes openjdk-8-jdk",
      "java -version",
      "echo --------------INSTALLING DOCKER-------------",
      "sudo apt-get update",
      "sudo apt-get remove --yes docker docker-engine docker.io",
      "sudo apt-get install --yes docker.io",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      # "echo --------------INSTALLING DOCKER-REGISTRY-------------",
      # "sudo curl -L 'https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose",
      # "sudo chmod +x /usr/local/bin/docker-compose",
      # "docker run -d -p 5000:5000 --restart=always --name registry registry:2",
      "echo --------------INSTALLING JENKINS-------------",
      "sudo apt-get update",
      "sudo apt-get install --yes daemon",
      "sudo apt-get update",
      "wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -",
      "sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'",
      "sudo apt-get update",
      "sudo apt-get install --yes jenkins",
      "echo --------------INSTALLING MAVEN-------------",
      "sudo apt-get update",
      "sudo apt-get install --yes maven",
      "echo --------------INSTALLING Python3-------------",
      "sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1",
      "sudo apt-get install --yes python-lxml",
      "echo --------------INSTALLING ANSIBLE-------------",
      "sudo apt-add-repository --yes ppa:ansible/ansible",
      "sudo apt-get update",
      "sudo apt-get install --yes ansible",
      # "echo --------------INSTALLING NEXUS-------------",
      # "cd ~",
      # "wget https://sonatype-download.global.ssl.fastly.net/nexus/3/nexus-3.24.0-02-unix.tar.gz",
      # "tar -С /opt -zxvf  nexus-3.24.0-02-unix.tar.gz",
      # "mv /opt/nexus-3.24.0-02 /opt/nexus",
      # "mv opt/nexus/bin/nexus.rc /opt/nexus/bin/nexus.rc.old",
      # "sudo chown -R ubuntu:ubuntu nexus/ sonatype-work/",
      # "echo NEXUS_HOME='/opt/nexus' >> ~/.bashrc",
      # "source ~/.bashrc",
      # "echo run_as_user='ubuntu' > /opt/nexus/bin/nexus.rc",
      # "sudo ln -s /opt/nexus/bin/nexus /etc/init.d/nexus",
      # "sudo systemctl start nexus",
    ]

    connection {
      user        = "ubuntu"
      type        = "ssh"
      private_key = file("../aws/aws_frankfurt_key.pem")
      host = aws_instance.DevTools.public_ip
    }
  }
}

# Nexus server
resource "aws_instance" "Nexus" {
  ami                    = "ami-0e342d72b12109f91"
  instance_type          = "t2.medium"
  key_name               = "aws_frankfurt_key"
  vpc_security_group_ids = [aws_security_group.artifactory_sg.id, aws_security_group.icmp_sg.id]
  subnet_id = aws_subnet.gw_public_subnet.id
  private_ip = "10.0.1.11"
  tags = {
    Name = "Nexus"
  }
  #get instance_ip
  provisioner "local-exec" {
    command = "echo Nexus ${aws_instance.Nexus.public_ip} >> ../public_ips.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "echo --------------INSTALLING JAVA-------------",
      "sudo apt-get update",
      "sudo apt-get install --yes openjdk-8-jre",
      "sudo apt-get install --yes openjdk-8-jdk",
      "java -version",
      "echo --------------INSTALLING Python3-------------",
      "sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1",
      "sudo apt-get install --yes python-lxml",
      "echo --------------INSTALLING NEXUS-------------",
      "cd ~",
      "wget https://sonatype-download.global.ssl.fastly.net/nexus/3/nexus-3.24.0-02-unix.tar.gz",
      "sudo tar -C /opt -zxvf nexus-3.24.0-02-unix.tar.gz",
      "sudo mv /opt/nexus-3.24.0-02 /opt/nexus",
      "sudo mv /opt/nexus/bin/nexus.rc /opt/nexus/bin/nexus.rc.old",
      "sudo chown -R ubuntu:ubuntu /opt/nexus/ /opt/sonatype-work/",
      "echo NEXUS_HOME='/opt/nexus' >> ~/.bashrc",
      "source ~/.bashrc",
      "echo run_as_user='ubuntu' > /opt/nexus/bin/nexus.rc",
      "sudo ln -s /opt/nexus/bin/nexus /etc/init.d/nexus",
      "sudo systemctl enable nexus",
      "sudo systemctl start nexus",
    ]

    connection {
      user        = "ubuntu"
      type        = "ssh"
      private_key = file("../aws/aws_frankfurt_key.pem")
      host = aws_instance.Nexus.public_ip
    }
  }
}


# QA server
resource "aws_instance" "QA" {
  ami                    = "ami-0e342d72b12109f91"
  instance_type          = "t2.micro"
  key_name               = "aws_frankfurt_key"
  vpc_security_group_ids = [aws_security_group.destination_sg.id, aws_security_group.icmp_sg.id]
  subnet_id = aws_subnet.gw_public_subnet.id
  private_ip = "10.0.1.20"
  tags = {
    Name = "QA"
  }
  #get instance_ip
  provisioner "local-exec" {
    command = "echo QA ${aws_instance.QA.public_ip} >> ../public_ips.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "echo --------------INSTALLING JAVA-------------",
      "sudo apt-get update",
      "sudo apt-get install --yes openjdk-8-jre",
      "sudo apt-get install --yes openjdk-8-jdk",
      "java -version",
      "echo --------------INSTALLING Python3-------------",
      "sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1",
      "sudo apt-get install --yes python-lxml",
    ]

    connection {
      user        = "ubuntu"
      type        = "ssh"
      private_key = file("../aws/aws_frankfurt_key.pem")
      host = aws_instance.QA.public_ip
    }
  }
}

# CI server
resource "aws_instance" "CI" {
  ami                    = "ami-0e342d72b12109f91"
  instance_type          = "t2.micro"
  key_name               = "aws_frankfurt_key"
  vpc_security_group_ids = [aws_security_group.destination_sg.id, aws_security_group.icmp_sg.id]
  subnet_id = aws_subnet.gw_public_subnet.id
  private_ip = "10.0.1.30"
  tags = {
    Name = "CI"
  }
  #get instance_ip
  provisioner "local-exec" {
    command = "echo CI ${aws_instance.CI.public_ip} >> ../public_ips.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "echo --------------INSTALLING JAVA-------------",
      "sudo apt-get update",
      "sudo apt-get install --yes openjdk-8-jre",
      "sudo apt-get install --yes openjdk-8-jdk",
      "java -version",
      "echo --------------INSTALLING Python3-------------",
      "sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1",
      "sudo apt-get install --yes python-lxml",
    ]

    connection {
      user        = "ubuntu"
      type        = "ssh"
      private_key = file("../aws/aws_frankfurt_key.pem")
      host = aws_instance.CI.public_ip
    }
  }
}

# Docker server
resource "aws_instance" "Docker" {
  ami                    = "ami-0e342d72b12109f91"
  instance_type          = "t2.micro"
  key_name               = "aws_frankfurt_key"
  vpc_security_group_ids = [aws_security_group.destination_sg.id, aws_security_group.icmp_sg.id]
  subnet_id = aws_subnet.gw_public_subnet.id
  private_ip = "10.0.1.40"
  tags = {
    Name = "Docker"
  }
  #get instance_ip
  provisioner "local-exec" {
    command = "echo Docker ${aws_instance.Docker.public_ip} >> ../public_ips.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "echo --------------INSTALLING JAVA-------------",
      "sudo apt-get update",
      "sudo apt-get install --yes openjdk-8-jre",
      "sudo apt-get install --yes openjdk-8-jdk",
      "java -version",
      "echo --------------INSTALLING Python3-------------",
      "sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1",
      "sudo apt-get install --yes python-lxml",
      "echo --------------INSTALLING DOCKER-------------",
      "sudo apt-get update",
      "sudo apt-get remove --yes docker docker-engine docker.io",
      "sudo apt-get install --yes docker.io",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
    ]

    connection {
      user        = "ubuntu"
      type        = "ssh"
      private_key = file("../aws/aws_frankfurt_key.pem")
      host = aws_instance.Docker.public_ip
    }
  }
}
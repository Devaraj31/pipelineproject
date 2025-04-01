provider "aws" {
  region = "us-east-1"
  access_key = "*********"
  secret_key = "***************************"
}

# ********* Creating a vpc *******************
resource "aws_vpc" "nv_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "nv_vpc"
  }
}

# ********************************************************************************************************************
# **************** Creating VPC peering connection **************************

data "aws_vpc" "default" {
  default = true
}

resource "aws_vpc_peering_connection" "nv_vpc_peering" {
  peer_vpc_id   = aws_vpc.nv_vpc.id
  vpc_id        = data.aws_vpc.default_id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = {
    Name = "nv_vpc-to-Default-VPC-Peering"
  }
}

resource "aws_vpc_peering_connection_accepter" "default_vpc_accepter" {
  vpc_peering_connection_id = aws_vpc_peering_connection.nv_vpc_peering.id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}
# *****************************************************************************
# ************************** Default VPC route table routing ******************

resource "aws_route" "default_vpc_route" {
  route_table_id            = data.aws_vpc.default.main_route_table_id
  destination_cidr_block    = aws_vpc.nv_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.nv_vpc_peering.id
}
# ******************* nv_vpc public route table routing ****************************
resource "aws_route" "nv_vpc_route_1" {
  route_table_id            = aws_route_table.nv_pub_rt.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.nv_vpc_peering.id
}

# ******************* nv_vpc private route table 1 routing ****************************
resource "aws_route" "nv_vpc_route_2" {
  route_table_id            = aws_route_table.nv_pvt_rt.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.nv_vpc_peering.id
}

# ******************* nv_vpc private route table 2 routing ****************************
resource "aws_route" "nv_vpc_route_3" {
  route_table_id            = aws_route_table.nv_pvt_rt_1.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.nv_vpc_peering.id
}



# *************************************************************************************************************************************************

# ***********  Creating public subnet ****************
resource "aws_subnet" "nv_pub_subnet" {
  vpc_id = aws_vpc.nv_vpc.id
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "nv_pub_subnet"
  }
}

# ************ creating a private subnet (subnet1)  *************
resource "aws_subnet" "nv_pvt_subnet_1" {
  vpc_id = aws_vpc.nv_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "nv_pvt_subnet-1"
  }
}

# ************ creating a private subnet (subnet2)  *************
resource "aws_subnet" "nv_pvt_subnet_2" {
  vpc_id = aws_vpc.nv_vpc.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "nv_pvt_subnet-2"
  }
}

# ********** creating a Internet Gateway ********************
resource "aws_internet_gateway" "nv_igw" {
  vpc_id = aws_vpc.nv_vpc.id
  tags = {
    Name = "nv_igw"
  }
}

# ****************** Elastic IP for Public NAT Gateway *********
resource "aws_eip" "nv_nat_gateway_eip" {
}

# ********** creating a NAT Gateway ****************************
resource "aws_nat_gateway" "nv_nat_gateway" {
  subnet_id = aws_subnet.nv_pub_subnet.id
  allocation_id = aws_eip.nv_nat_gateway_eip.id
  
  tags = {
    Name = "nv_nat_gateway"
  }
}


# ***************** Creating a public route table ***********************
resource "aws_route_table" "nv_pub_rt" {
  vpc_id = aws_vpc.nv_vpc.id
  
  route {
    cidr_block = "10.0.0.0/16"
	gateway_id = "local"
  }
  
  route {
    cidr_block = "0.0.0.0/0"
	gateway_id = aws_internet_gateway.nv_igw.id
  }
  
  tags = {
    Name = "nv_pub_rt"
  }
}

# ***************** Creating a private route table with NAT Gateway ***********************
resource "aws_route_table" "nv_pvt_rt" {
  vpc_id = aws_vpc.nv_vpc.id
  
  route {
    cidr_block = "10.0.0.0/16"
	gateway_id = "local"
  }
  
  route {
    cidr_block = "0.0.0.0/0"
	gateway_id = aws_nat_gateway.nv_nat_gateway.id
  }
  
  tags = {
    Name = "nv_pvt_rt"
  }
}


# ***************** Creating a private route table without NAT Gateway ***********************
resource "aws_route_table" "nv_pvt_rt_1" {
  vpc_id = aws_vpc.nv_vpc.id
  
  route {
    cidr_block = "10.0.0.0/16"
	gateway_id = "local"
  }
  
  route {
    cidr_block = "0.0.0.0/0"
	gateway_id = aws_nat_gateway.nv_nat_gateway.id
  }
  
  tags = {
    Name = "nv_pvt_rt_1"
  }
}

# ***************** Public route table association **************
resource "aws_route_table_association" "pub_sub_rt" {
  subnet_id = aws_subnet.nv_pub_subnet.id
  route_table_id = aws_route_table.nv_pub_rt.id
}

# ***************** Private route table association With NAT Gateway **************
resource "aws_route_table_association" "pvt_sub_rt_1" {
  subnet_id = aws_subnet.nv_pvt_subnet_1.id
  route_table_id = aws_route_table.nv_pvt_rt.id
}

# ***************** Private route table association without NAT gateway **************
resource "aws_route_table_association" "pvt_sub_rt_2" {
  subnet_id = aws_subnet.nv_pvt_subnet_2.id
  route_table_id = aws_route_table.nv_pvt_rt_1.id
}

# ************ Creating public Security group **********************
resource "aws_security_group" "nv_pub_sg" {
  vpc_id        = aws_vpc.nv_vpc.id
  
   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["10.0.0.0/16"]
   }
   
   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["172.31.0.0/16"]
   }
   
   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
   }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "pub_SG"
  }
}

# ************ Creating private Security group **********************
resource "aws_security_group" "nv_pvt_sg" {
  vpc_id        = aws_vpc.nv_vpc.id
  
   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["10.0.0.0/16"]
   }
   
   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["172.31.0.0/16"]
   }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "pvt_SG"
  }
}


# *************  Creating an EC2 instance as Jenkins Master *****************
resource "aws_instance" "jenkins-master" {
  ami                         = "ami-0f9de6e2d2f067fca"
  instance_type               = "t2.micro"
  key_name                    = "Nv-practice"
  subnet_id                   = aws_subnet.nv_pub_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nv_pub_sg.id]
# user_data = file ("${path.module}/jenkins.sh")
  
  tags = {
    Name = "jenkins-master"
  }
}

# *************  Creating an EC2 instance as Kubernetes Master *****************
resource "aws_instance" "k8s-master" {
  ami                    = "ami-0f9de6e2d2f067fca"
  instance_type          = "t2.medium"
  key_name               = "Nv-practice"
  vpc_security_group_ids = [aws_security_group.nv_pvt_sg.id]
  subnet_id              = aws_subnet.nv_pvt_subnet_1.id
  
  tags = {
    Name = "Kubernetes-Master"
  }
}

# *************  Creating an EC2 instance as Kubernetes Slave *****************
resource "aws_instance" "k8s-slave" {
  ami                    = "ami-0f9de6e2d2f067fca"
  instance_type          = "t2.micro"
  key_name               = "Nv-practice"
  vpc_security_group_ids = [aws_security_group.nv_pvt_sg.id]
  subnet_id              = aws_subnet.nv_pvt_subnet_2.id
  
  tags = {
    Name = "Kubernetes-Slave"
  }
}

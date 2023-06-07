provider "aws" {
  region = "us-east-1"
}

//vpc
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

//public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "public_subnet"
  }

}

//private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "private_subnet"
  }

}

//internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "igw"
  }
}

//Elastic IP
resource "aws_eip" "elasticip" {
  instance = aws_instance.linux_instance.id
}

//nat gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.elasticip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "ngw"
  }
}

// public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

//public route table association
resource "aws_route_table_association" "public_rt_assocation" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

// private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private_rt"
  }
}

//private route table association
resource "aws_route_table_association" "private_rt_assocation" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}


//security group
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "allow SSH connection"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

//linux ec2 instance
resource "aws_instance" "linux_instance" {
  ami                    = "ami-0715c1897453cabd1"
  instance_type          = "t2.micro"
  key_name               = "anlinuxtest"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
}

//EBS volume
resource "aws_ebs_volume" "ebs-vol" {
  size              = 1
  availability_zone = "us-east-1"
  tags = {
    Name = "ebs-vol"
  }
}

// EBS volume attachment to EC2
resource "aws_volume_attachment" "attachment-vol" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs-vol.id
  instance_id = aws_instance.linux_instance.id
}

//S3
resource "aws_s3_bucket" "storage_bucket" {
  bucket = "static-s3-storage-bucket-an-425662023"
}

//IAM role
resource "aws_iam_role" "ec2_s3" {
  name = "ec2-s3"

  assume_role_policy = jsonencode({
    Version = "2023-06-06"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Action = [
          "*"
        ],
        Resource = [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::static-s3-storage-bucket-an-425662023"
        ]
        Sid = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

//IAM role policy
resource "aws_iam_role_policy_attachment" "ec2_s3_policy" {
  role       = aws_iam_role.ec2_s3.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

//IAM instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_s3.name
}


provider "aws" {
  region = "us-east-1"  # Set your preferred AWS region
}

# Automatically fetch the latest Amazon Linux 2 AMI in the chosen region
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Automatically fetch the latest Ubuntu 22.04 AMI in the chosen region (Uncomment to use)
# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"]  # Canonical (Ubuntu) owner ID

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# EC2 instance resource using the automatically selected AMI
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id  # Use the fetched AMI ID
  instance_type = "t2.micro"
  key_name      = "terraform"  # Replace with your existing SSH key name

  tags = {
    Name = "MyAutomatedInstance"
  }
}

# Optionally add an EBS volume if needed (for persistence)
resource "aws_ebs_volume" "example" {
  availability_zone = "us-east-1a"  # Ensure this is in the same AZ as the EC2 instance
  size              = 8  # Volume size in GB
  volume_type       = "gp2"

  tags = {
    Name = "MyEBSVolume"
  }
}

# Attach the EBS volume to the EC2 instance
resource "aws_volume_attachment" "example" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_instance.example.id
}

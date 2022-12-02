packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "custom-ami-{{timestamp}}"
  instance_type = "t2.micro"
  region        = "eu-west-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  tags = {
    Name = "my-app"
    Os   = "ubuntu-jammy-22.04-amd64-server"
  }
}

build {
  name = "custom-ami"
  sources = ["source.amazon-ebs.ubuntu"]
    post-processor "manifest" {
        output = "manifest.json"
        strip_path = true
    }
}

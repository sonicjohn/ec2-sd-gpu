resource "aws_vpc" "sd_network" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "sd-network"
  }
}

locals {
  AWS_AVAIL_ZONE = "${var.AWS_DEFAULT_REGION}${var.AWS_AZ}"
}

resource "aws_subnet" "sd_public" {
  vpc_id                  = aws_vpc.sd_network.id
  cidr_block              = "192.168.200.0/24"
  availability_zone       = local.AWS_AVAIL_ZONE
  map_public_ip_on_launch = true
  tags = {
    Name = "sd-public"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.sd_network.id
  tags = {
    Name = "sd-gw"
  }
}

resource "aws_route_table" "sd_rt" {
  vpc_id = aws_vpc.sd_network.id

  tags = {
    Name = "sd-rt"
  }
}

resource "aws_route_table_association" "sd_default" {
  subnet_id      = aws_subnet.sd_public.id
  route_table_id = aws_route_table.sd_rt.id
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.sd_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_security_group" "sd_allow_rdp" {
  name        = "allow_rdp"
  description = "Allow RDP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.sd_network.id

  tags = {
    Name = "allow_rdp"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_rdp_ipv4" {
  security_group_id = aws_security_group.sd_allow_rdp.id
  cidr_ipv4         = var.RDP_IP_ADDRESS == "" ? "0.0.0.0/0" : "${var.RDP_IP_ADDRESS}/32"
  from_port         = 3389
  ip_protocol       = "tcp"
  to_port           = 3389
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.sd_allow_rdp.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_iam_role" "stable_diffusion_instance_role" {
  name_prefix = "StableDiffusionInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "stable_diffusion_role_policy_attachment" {
  role = aws_iam_role.stable_diffusion_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "stable_diffusion_instance_profile" {
  role = aws_iam_role.stable_diffusion_instance_role.name
}

# ED25519 key and keypair
resource "tls_private_key" "tf_default" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "tf_default" {
  key_name   = "ec2_gpu_tf_default"
  public_key = tls_private_key.tf_default.public_key_openssh
}

/*
resource "local_file" "admin_pw_file" {
    #content  = local.admin_pw
    content = "${rsadecrypt(aws_instance.windows_stable_diffusion.password_data,file("/home/jcarnes/.aws_tf/MOBILE5_WIN_EC2.pem"))}"
    filename = "/home/jcarnes/.aws_tf/${aws_instance.windows_stable_diffusion.id}"
    directory_permission = "0700"
    file_permission = "0600"
}

resource "local_file" "admin_rdp_file" {
    #content = local.rdp_content
    content = join("\r",
    [
      "auto connect:i:1",
      "full address:s:${aws_instance.windows_stable_diffusion.public_ip}",
      "username:s:Administrator"
    ])
    filename = "/home/jcarnes/.aws_tf/${aws_instance.windows_stable_diffusion.id}.rdp"
    directory_permission = "0700"
    file_permission = "0600"
}
*/

resource "aws_instance" "windows_stable_diffusion" {

  # AMI specification
  ami                    = data.aws_ami.windows.id # most recent Server 2022 AMI
  #ami                    = "ami-049496b4104e8c810" # has SD with models and Steam Client; us-west2

  instance_market_options {
   market_type = var.SPOT_OR_ON_DEMAND != "" ? var.SPOT_OR_ON_DEMAND : "spot"
   spot_options {
    instance_interruption_behavior = "stop"
    spot_instance_type = "persistent"
   }
  }

  # prices for us-west-2 as of 3/2024
  instance_type          = "g4dn.xlarge" # 4 CPU; 16 Mem; spot: $0.2437; on-demand: $0.526
  #instance_type          = "g4dn.2xlarge" # 8 CPU; 16 Mem; spot: $0.4453; on-demand: $0.752
  #instance_type          = "g4dn.4xlarge" # 16 CPU; 64 Mem; spot: $0.8564; on-demand: $1.204
  #instance_type          = "g4dn.8xlarge" # 32 CPU; 128 Mem; spot: $1.6896; on-demand: $2.176
  #instance_type          = "g4dn.16xlarge" # 64 CPU; 256 Mem; spot: $3.3792; on-demand: $4.352

  availability_zone      = local.AWS_AVAIL_ZONE
  subnet_id              = aws_subnet.sd_public.id
  vpc_security_group_ids = [aws_security_group.sd_allow_rdp.id]
  key_name                = var.AWS_KEYPAIR_NAME != "" ? var.AWS_KEYPAIR_NAME : "ec2_gpu_tf_default"
  user_data              = file("userdata.tpl") # work in progress
  #get_password_data      = "true" # enable to create admin_pw_file
  iam_instance_profile   = aws_iam_instance_profile.stable_diffusion_instance_profile.name

  tags = {
    Name = "Win Stable Diffusion"
  }

  lifecycle {
    ignore_changes = [ami]
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 200
  }

}



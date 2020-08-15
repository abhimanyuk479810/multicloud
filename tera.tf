provider "aws" {
   region  = "ap-south-1"
   profile  = "abhimanyu"
}
#creating key pair
 resource  "tls_private_key" "task1_key"{
  algorithm  = "RSA"
}

 resource "local_file"  "mykey_file"{
   content  = tls_private_key.task1_key.private_key_pem
   filename = "mykey.pem"
}
 resource "aws_key_pair" "mygenerate_key"{
   key_name = "mykey"
   public_key = tls_private_key.task1_key.public_key_openssh
}

#creating security group
resource "aws_security_group" "task1_securitygroup" {
  name        = "task1_securitygroup"
  description = "Allow http and ssh traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



# Creating an aws instance by jthe use of key pair and security group

variable "ami_id" {
  default = "ami-052c08d70def0ac62"
}

resource  "aws_instance" "myos" {
  ami           = var .ami_id
  instance_type = "t2.micro"
  key_name = aws_key_pair.mygenerate_key.key_name 
  security_groups = [aws_security_group.task1_securitygroup.name]
  vpc_security_group_ids = [aws_security_group.task1_securitygroup.id]
  connection {
       type             = "ssh"
       user             = "ec2-user"
       private_key = tls_private_key.task1_key.private_key_pem
       port             = 22
       host             = aws_instance.myos.public_ip
}

    provisioner  "remote-exec" {
                    inline = [
                                "sudo yum install httpd -y",
                                "sudo systemctl start httpd",
                                "sudo systemctl enable httpd",
                                "sudo yum install git -y"
]
}
    tags = {
           Name = "task1 myos"
    }
}

#creating EBS volume

resource "aws_ebs_volume" "myvolume" {
  availability_zone = aws_instance.myos.availability_zone 
  size                      = 1

  tags = {
    Name = "ebsvol"
  }
}

# Attaching created volume to existing ec2 instance
resource "aws_volume_attachment" "ebs_att" {
  device_name  =  "/dev/sdh"
  volume_id   = aws_ebs_volume.myvolume.id
  instance_id =  aws_instance.myos.id
  force_detach = true
}

# Mount the  volume 

resource  "null_resource"  "partition_and_mount" {
depends_on = [
         aws_volume_attachment.ebs_att,
]

     connection {
         type              =  "ssh"
         user              = "ec2-user"
         private_key  = tls_private_key.task1_key.private_key_pem
         host              =  aws_instance.myos.public_ip
       }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh   /var/www/html",
      "sudo rm -rf  /var/www/html/*",
      "sudo git clone https://github.com/abhimanyuk479810/multicloud.git  /var/www/html/",
       "sudo setenforce 0"
    ]
  }
}




  resource "aws_s3_bucket" "mybucket1" {
  bucket = "abhimanyu0413"
  acl    = "public-read"

  tags = {
    Name        = "taskbucket"
  }
}  

locals {

s3_origin_id = "myS3origin"
} 



resource "aws_s3_bucket_object" "object" {
  bucket           =  aws_s3_bucket.mybucket1.id
  key                 = "logo-via-logohub.png"
  source            = "C:/Users/abhimanyu/Downloads/logo-via-logohub.png"
  acl                  = "public-read"
  content_type = "image or png"
}




resource "aws_cloudfront_distribution" "s3_dist" {
  origin {
        domain_name =  aws_s3_bucket.mybucket1.bucket_regional_domain_name
         origin_id        =  local.s3_origin_id

         custom_origin_config  {
                   http_port                         =  80
                   https_port                       =  80
                   origin_protocol_policy   = "match-viewer"
                   origin_ssl_protocols       = [ "TLSv1" , "TLSv1.1" , "TLSv1.2" ]
    }
  }

   enabled =  true

 default_cache_behavior {
           
    allowed_methods  = [ "DELETE","GET","HEAD","OPTIONS","PATCH","POST","PUT" ]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

     viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
   
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

    viewer_certificate  {
            cloudfront_default_certificate = true
  }
}

resource  "null_resource"  "image" {
depends_on = [
       aws_instance.myos, 
       aws_volume_attachment.ebs_att,
       aws_cloudfront_distribution.s3_dist
]

 connection {
         type              =  "ssh"
         user              = "ec2-user"
         private_key  = tls_private_key.task1_key.private_key_pem
         host              =  aws_instance.myos.public_ip
       }

provisioner "remote-exec" {
    inline = [
    
    
      " echo  < 'img noSrc ='https://${aws_cloudfront_distribution.s3_dist.domain_name}/logo-via-logohub.png'>' | sudo tee -a  /var/www/html/index.html"
        ]
      }
}

output "myosip"  {
            value = aws_instance.myos.public_ip
}

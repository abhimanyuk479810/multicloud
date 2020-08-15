# Create/Launch Application On AWS Cloud Using Terraform
# what we have to do.
1. Create the key and security group which allows the port 80.
2. Launch EC2 instance.
3. In this Ec2 instance use the key and security group which we have created in step 1.
4. Launch one Volume (EBS) and mount that volume into /var/www/html
5. Developer has uploaded the code into GitHub repo also the repo has some images.
6. Copy the GitHub repo code into /var/www/html
7. Create an S3 bucket, and copy/deploy the images from GitHub repo into the s3 bucket and change the permission to public readable.
8. Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html

## Let's start,</br>
First of all, create an IAM user in your AWS account and then configure it by using the command.</br>



# STEP  TO COMPLETE THE TASK

# 1. Verify the provider as AWS with profile and region
provider "aws" {</br>
region = "ap-south-1"</br>
profile = "abhimanyu"</br>
}</br>

 # 2. Create the key pair and save it to use for the instance login
resource "tls_private_key" "task1_key"{</br>
algorithm = "RSA"</br>
}</br>

resource "local_file" "mykey_file"{</br>
content = tls_private_key.task1_key.private_key_pem</br>
filename = "mykey.pem"</br>
}</br>

resource "aws_key_pair" "mygenerate_key"{</br>
key_name = "mykey"</br>
public_key = tls_private_key.task1_key.public_key_openssh</br>
}</br>




 # 3. Create a security group allowing port 22 for ssh login and allowing port 80 for  HTTP protocol.
resource "aws_security_group" "task1_securitygroup" {</br>
name = "task1_securitygroup"</br>
description = "Allow http and ssh traffic"</br>

ingress {</br>
from_port = 22</br>
to_port = 22</br>
protocol = "tcp"</br>
cidr_blocks = ["0.0.0.0/0"]</br>
}</br>

ingress {</br>
from_port = 80</br>
to_port = 80</br>
protocol = "tcp"</br>
cidr_blocks = ["0.0.0.0/0"]</br>
}</br>

egress {</br>
from_port = 0</br>
to_port = 0</br>
protocol = "-1"</br>
cidr_blocks = ["0.0.0.0/0"]</br>
}</br>
}</br>



# 4. In the EC2 instance use the key and security group which we have created with automatic login into the instance and download the httpd and git.
variable "ami_id" {</br>
default = "ami-052c08d70def0ac62"</br>
}</br>

resource "aws_instance" "myos" {</br>
ami = var .ami_id</br>
instance_type = "t2.micro"</br>
key_name = aws_key_pair.mygenerate_key.key_name</br>
security_groups = [aws_security_group.task1_securitygroup.name]</br>
vpc_security_group_ids = [aws_security_group.task1_securitygroup.id]</br>

connection {</br>
type = "ssh"</br>
user = "ec2-user"</br>
private_key = tls_private_key.task1_key.private_key_pem</br>
port = 22</br>
host = aws_instance.myos.public_ip</br>
}</br>

provisioner "remote-exec" {</br>
inline = [</br>
"sudo yum install httpd -y",</br>
"sudo systemctl start httpd",</br>
"sudo systemctl enable httpd",</br>
"sudo yum install git -y"</br>
]</br>
}</br>

tags = {</br>
Name = "task1 myos"</br>
}</br>
}</br>



# 5.Create EBS volume
resource "aws_ebs_volume" "myvolume" {</br>
availability_zone = aws_instance.myos.availability_zone</br>
size = 1</br>

tags = {</br>
Name = "ebsvol"</br>
}</br>
}</br>




# 6.Attaching created volume to existing ec2 instance
resource "aws_volume_attachment" "ebs_att" {</br>
device_name = "/dev/sdh"</br>
volume_id = aws_ebs_volume.myvolume.id</br>
instance_id = aws_instance.myos.id</br>
force_detach = true</br>
}</br>




# 7. Mount the volume
resource "null_resource" "partition_and_mount" {</br>
depends_on = [</br>
aws_volume_attachment.ebs_att,</br>
]</br>


connection {</br>
type = "ssh"</br>
user = "ec2-user"</br>
private_key = tls_private_key.task1_key.private_key_pem</br>
host = aws_instance.myos.public_ip</br>
}</br>


provisioner "remote-exec" {</br>
inline = [</br>
"sudo mkfs.ext4 /dev/xvdh",</br>
"sudo mount /dev/xvdh /var/www/html",</br>
"sudo rm -rf /var/www/html/*",</br>
"sudo git clone https://github.com/abhimanyuk479810/multicloud.git /var/www/html/",</br>
"sudo setenforce 0"</br>
]</br>
}</br>
}</br>

# 8.Creating an S3 bucket and make it public readable
resource "aws_s3_bucket" "mybucket1" {</br>
bucket = "abhimanyu0413"</br>
acl = "public-read"</br>

tags = {</br>
Name = "taskbucket"</br>
}</br>
}</br>

locals {</br>

s3_origin_id = "myS3origin"</br>
}</br>


















# 9. Upload the image in this s3 bucket.
resource "aws_s3_bucket_object" "object" {</br>
bucket = aws_s3_bucket.mybucket1.id</br>
key = "logo-via-logohub.png"</br>
source = "C:/Users/abhimanyu/Downloads/logo-via-logohub.png"</br>
acl = "public-read"</br>
content_type = "image or png"</br>
}</br>




  
# 10. Creating CloudFront with S3 as origin to provide CDN(content delevery network)
resource "aws_cloudfront_distribution" "s3_dist" {</br>
origin {</br>
domain_name = aws_s3_bucket.mybucket1.bucket_regional_domain_name</br>
origin_id = local.s3_origin_id</br>


custom_origin_config {</br>
http_port = 80</br>
https_port = 80</br>
origin_protocol_policy = "match-viewer"</br>
origin_ssl_protocols = [ "TLSv1" , "TLSv1.1" , "TLSv1.2" ]</br>
}</br>
}</br>

enabled = true</br>

default_cache_behavior {</br>

allowed_methods = [ "DELETE","GET","HEAD","OPTIONS","PATCH","POST","PUT" ]</br>
cached_methods = ["GET", "HEAD"]</br>
target_origin_id = local.s3_origin_id</br>


forwarded_values {</br>
query_string = false</br>

cookies {</br>
forward = "none"</br>
}</br>
}</br>

viewer_protocol_policy = "allow-all"</br>
min_ttl = 0</br>
default_ttl = 3600</br>
max_ttl = 86400</br>

}</br>

restrictions {</br>
geo_restriction {</br>
restriction_type = "none"</br>
}</br>
}</br>


viewer_certificate {</br>
cloudfront_default_certificate = true</br>
}</br>
}</br>


resource "null_resource" "image" {</br>
depends_on = [</br>
aws_instance.myos,</br>
aws_volume_attachment.ebs_att,</br>
aws_cloudfront_distribution.s3_dist</br>
]</br>

connection {</br>
type = "ssh"</br>
user = "ec2-user"</br>
private_key = tls_private_key.task1_key.private_key_pem</br>
host = aws_instance.myos.public_ip</br>
}</br>


provisioner "remote-exec" {</br>
inline = [</br>


" echo < 'img noSrc ='https://${aws_cloudfront_distribution.s3_dist.domain_name}/logo-via-logohub.png'>' | sudo tee -a /var/www/html/index.html"</br>
]</br>
}</br>
}</br>

output "myosip" {</br>
value = aws_instance.myos.public_ip</br>
}</br>



# 11. Save all the code in one file and run the following command
terraform initterraform validateterraform apply -auto-approve</br>




# 12. After apply completed successfully we get own desire web server



That's all about how to launch Application on AWS using Terraform, feel free to give the feedback.</br>

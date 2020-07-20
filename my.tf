provider "aws" {
  region = "ap-south-1"
  profile = "myprofile"
}
#Creating Security Group
resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_http_ssh"
  description = "Allow SSh and HTTP inbound traffic"
  vpc_id      = "vpc-02f3ee6a" 
  ingress {
    description = "for ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "for http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_ssh_http"
  }
}
#creating instance
resource "aws_instance" "myin" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1b"
  key_name      =  "mykey1122"
  security_groups = [ "${aws_security_group.allow_ssh_http.name}" ]
  associate_public_ip_address = "1"


  provisioner "remote-exec" {
    connection {
    agent    = "false"
    type     = "ssh"
    port     =  22
    user     = "ec2-user"
    private_key = file("C:/Users/hp/Downloads/mykey1122.pem")
    host     = aws_instance.myin.public_ip
  }


    inline = [
      "sudo yum install httpd  amazon-efs-utils nfs-utils php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "MyOS"
  }
}
#Launching EFS
resource "aws_efs_file_system" "myefs"{   
 creation_token="my-efs"      
 tags = {  
  Name= "myfs"    
 }  
}   
#Mounting EFS 
resource "aws_efs_mount_target" "alpha" {
  depends_on =  [ aws_efs_file_system.myefs,]
  file_system_id = aws_efs_file_system.myefs.id
  subnet_id      = aws_instance.myin.subnet_id
  security_groups = ["${aws_security_group.allow_ssh_http.id}"]
}
resource "null_resource" "nullremote3"  {
  depends_on = [aws_efs_mount_target.alpha,]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    port     =  22
    private_key = file("C:/Users/hp/Downloads/mykey1122.pem")
    host     = aws_instance.myin.public_ip
  }
  provisioner "remote-exec" {
  inline = [
      "sudo mount -t nfs4 ${aws_efs_mount_target.alpha.ip_address}:/ /var/www/html/", 
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/ShirshaDatta/Using-Terraform-to-use-EFS.git  /var/www/html/"
  ]
}
}
##########
/*
resource "aws_s3_bucket" "bucket1" {    
 bucket = "bucket1"    
 acl    = "public-read"      
 versioning {      
  enabled = true  
   }   
 tags = {      
  Name = "bucket1"      
  Environment = "Dev"    
 }
}
resource "aws_s3_bucket_object" "s3obj" {
 depends_on = [
    aws_s3_bucket.bucket1,
]
  bucket       = "bucket1"
  key          = "automatiiion.jpg"
  source       = "D:/google downloads/automatiiion.jpg"
  acl          = "public-read"
  content_type = "image or jpeg"
}
*/
#Creating S3 bucket
resource "aws_s3_bucket" "bucket" {    
 bucket = "bb304"    
 acl    = "public-read"      
 region = "ap-south-1"
 versioning {      
  enabled = true  
   }   
 tags = {      
  Name = "bucket1" 
 }
}
#Uploading on S3 bucket
resource "aws_s3_bucket_object" "object" {
  depends_on = [
    aws_s3_bucket.bucket,
]
  bucket       = "bb304"
  key          = "task2.jpeg"
  source       = "task2.jpeg"
  acl          = "public-read"
  content_type = "image or jpeg"
}

locals {
  s3_origin_id = "myS3Origin"
}
#cloudfront
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "OAI"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             =  "task2 image"
  default_root_object = "task2.jpeg"
default_cache_behavior {
    allowed_methods  = ["DELETE","GET", "HEAD","OPTIONS", "PATCH", "POST", "PUT"]
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
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false
      headers      = ["Origin"]


      cookies {
        forward = "none"
      }
    }


    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }


  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }


    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }


  price_class = "PriceClass_200"
restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/hp/Downloads/mykey1122.pem")
    host     = aws_instance.myin.public_ip
  }

  // Generate Cloudfront URL for image and append to the HTML Page
  provisioner "remote-exec" {
    inline = [
      "sudo su << EOF",
      "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.object.key}' height='200px' width='200px'>\" >> /var/www/html/index.php",
      "EOF",
    ]
  }
}


#output "instance_id" {
#  value = "${aws_instance.windows_stable_diffusion.id}"
#}

#output "admin_pw" {
#    value =  "${rsadecrypt(aws_instance.windows_stable_diffusion.password_data,file("/home/jcarnes/.aws_tf/MOBILE5_WIN_EC2.pem"))}"
#}

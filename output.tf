output "public_ips" {
  value = ["${var.connections}"]

  depends_on  = ["null_resource.lb"]
}

resource "null_resource" "lb" {
  count       = "${var.count}"

  triggers {
    hapxy_cfg = "${data.template_file.haproxy_cfg.rendered}"
  }

  connection {
    host  = "${element(var.connections, count.index)}"
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "[ -d /etc/haproxy ] || mkdir -p /etc/haproxy"
    ]
  }

  provisioner "file" {
    content     = "${data.template_file.haproxy_cfg.rendered}"
    destination = "/etc/haproxy/kuber_halb.cfg"
  }

  # deploy
  provisioner "remote-exec" {
    inline = [
      "docker ps -a | grep kuber_halb | awk '{print \"docker stop \"$1\" && docker rm \"$1}' | sh",
      "docker run -d --name=kuber_halb --restart=always -p ${var.port}:${var.port} -v /etc/haproxy:/etc/haproxy:ro haproxy:1.8.9-alpine haproxy -f /etc/haproxy/kuber_halb.cfg"
    ]
  }

  # rewrite kubelet
  provisioner "remote-exec" {
    inline = [
      "sed -i 's#server:.*#server: https://127.0.0.1:${var.port}#g' /etc/kubernetes/kubelet.conf",
      "systemctl restart kubelet.service"
    ]
  }

  # Destroy
  provisioner "remote-exec" {
    when = "destroy"
    inline = [
      "sed -i 's#server:.*#server: https://${var.api_endpoints[0]}#g' /etc/kubernetes/kubelet.conf",
      "systemctl restart kubelet.service",
      "docker ps -a | grep kuber_halb | awk '{print \"docker stop \"$1\" && docker rm \"$1}' | sh"
    ]
    on_failure = "continue"
  }
}

resource "null_resource" "update_kube_proxy" {
  count       = "${var.count > 0 ? 1 : 0}"
  depends_on  = ["null_resource.lb"]

  connection {
    host  = "${var.master_connection}"
    user  = "root"
    agent = true
  }

  # return kube-proxy's config to back
  provisioner "remote-exec" {
    when = "destroy"
    inline = [
      "kubectl get configmap -n kube-system kube-proxy -o yaml > kube-proxy-cm.yaml",
      "sed -i 's#server:.*#server: https://${var.api_endpoints[0]}#g' kube-proxy-cm.yaml",
      "kubectl apply -f kube-proxy-cm.yaml --force",
      "kubectl delete pod -n kube-system -l k8s-app=kube-proxy"
    ]
    on_failure = "continue"
  }

  # rewrite kube-proxy
  provisioner "remote-exec" {
    inline = [
      "kubectl get configmap -n kube-system kube-proxy -o yaml > kube-proxy-cm.yaml",
      "sed -i 's#server:.*#server: https://127.0.0.1:${var.port}#g' kube-proxy-cm.yaml",
      "kubectl apply -f kube-proxy-cm.yaml --force",
      "kubectl delete pod -n kube-system -l k8s-app=kube-proxy"
    ]
  }
}

data "template_file" "haproxy_cfg" {
  template = "${file("${path.module}/templates/haproxy.cfg")}"

  vars {
    port                = "${var.port}"
    check_interval      = "${var.check_interval}"
    down_interval       = "${var.down_interval}"
    rise_count          = "${var.rise_count}"
    fall_count          = "${var.fall_count}"
    slowstart_interval  = "${var.slowstart_interval}"
    max_connections     = "${var.max_connections}"
    max_queue           = "${var.max_queue}"
    servers             = "${indent(2, join("\n", formatlist("server %s %s check", var.api_endpoints, var.api_endpoints)))}"
  }
}

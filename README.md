# Kubernetes High Availability Service

## Key features

* Based on HAProxy
* Configurable availability parameters (with optimized default values)
* Proper apply/destroy

## Interfaces

### Input variables

* count - count of connections
* connections - public ips where applied
* master_connection - connection to any master server
* api_endpoints - list of master's api endpoint
* port - lb port (default: 16443)
* check_interval - The parameter sets the interval between two consecutive health checks (default: 10s)
* down_interval - The parameter sets the interval between checks depending on the server state (default: 5s)
* rise_count - The parameter states that a server will be considered as operational after <count> consecutive successful health checks (default: 2)
* fall_count - The parameter states that a server will be considered as dead after <count> consecutive unsuccessful health checks (default: 2)
* slowstart_interval - The parameter for a server accepts a interval which indicates after how long a server which has just come back up will run at full speed (default: 60s)
* max_connections - The parameter specifies the maximal number of concurrent connections that will be sent to this server (default: 250)
* max_queue - The parameter specifies the maximal number of connections which will wait in the queue for this server (default: 256)

### Output variables

* public_ips - public ips of instances/servers


## Example

```
variable "token" {}
variable "master_hosts" {
  default = 1
}
variable "worker_hosts" {
  default = 3
}

variable "docker_opts" {
  type = "list"
  default = ["--iptables=false", "--ip-masq=false"]
}

provider "hcloud" {
  token = "${var.token}"
}

module "provider_master" {
  source = "git::https://github.com/suquant/tf_hcloud.git?ref=v1.0.0"

  count = "${var.master_hosts}"
  token = "${var.token}"

  name        = "master"
  server_type = "cx21"
}

module "provider_worker" {
  source = "git::https://github.com/suquant/tf_hcloud.git?ref=v1.0.0"

  count = "${var.worker_hosts}"
  token = "${var.token}"

  name        = "worker"
  ssh_names   = ["${module.provider_master.ssh_names}"]
  ssh_keys    = []
  server_type = "cx11"
}

module "wireguard" {
  source = "git::https://github.com/suquant/tf_wireguard.git?ref=v1.0.0"

  count         = "${var.master_hosts}"
  connections   = ["${module.provider_master.public_ips}"]
  private_ips   = ["${module.provider_master.private_ips}"]
}


module "etcd" {
  source = "git::https://github.com/suquant/tf_etcd.git?ref=v1.0.0"

  count       = "${var.master_hosts}"
  connections = "${module.provider_master.public_ips}"

  hostnames   = "${module.provider_master.hostnames}"
  private_ips = ["${module.wireguard.ips}"]
}

module "docker_master" {
  source = "git::https://github.com/suquant/tf_docker.git?ref=v1.0.0"

  count       = "${var.master_hosts}"
  # Fix of conccurent apt install running: will run only after wireguard has been installed
  connections = ["${module.wireguard.public_ips}"]

  docker_opts = ["${var.docker_opts}"]
}

module "kuber_master" {
  source = "git::https://github.com/suquant/tf_kuber_master.git?ref=v1.0.0"

  count           = "${var.master_hosts}"
  connections     = ["${module.docker_master.public_ips}"]

  private_ips     = ["${module.provider_master.private_ips}"]
  etcd_endpoints  = "${module.etcd.client_endpoints}"
}

module "docker_worker" {
  source = "git::https://github.com/suquant/tf_docker.git?ref=v1.0.0"

  count       = "${var.worker_hosts}"
  connections = ["${module.provider_worker.public_ips}"]

  docker_opts = ["${var.docker_opts}"]
}

module "kuber_worker" {
  source = "git::https://github.com/suquant/tf_kuber_worker.git?ref=v1.0.0"

  count       = "${var.worker_hosts}"
  connections = ["${module.docker_worker.public_ips}"]

  join_command        = "${module.kuber_master.join_command}"
  kubernetes_version  = "${module.kuber_master.kubernetes_version}"
}

module "kuber_halb" {
  source = "git::https://github.com/suquant/tf_kuber_halb.git?ref=v1.0.0"

  count       = "${var.master_hosts + var.worker_hosts}"
  connections = ["${concat(module.kuber_master.public_ips, module.kuber_worker.public_ips)}"]

  master_connection = "${module.kuber_master.public_ips[0]}"
  api_endpoints     = ["${module.kuber_master.api_endpoints}"]
}
```
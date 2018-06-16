variable "count" {}

variable "connections" {
  type = "list"
}

variable "master_connection" {}

variable "port" {
  default = "16443"
}

variable "api_endpoints" {
  type = "list"
}

variable "check_interval" {
  description = "The parameter sets the interval between two consecutive health checks"
  default = "10s"
}

variable "down_interval" {
  description = "The parameter sets the interval between checks depending on the server state"
  default = "5s"
}

variable "rise_count" {
  description = "The parameter states that a server will be considered as operational after <count> consecutive successful health checks"
  default = "2"
}

variable "fall_count" {
  description = "The parameter states that a server will be considered as dead after <count> consecutive unsuccessful health checks"
  default = "2"
}

variable "slowstart_interval" {
  description = "The parameter for a server accepts a interval which indicates after how long a server which has just come back up will run at full speed"
  default = "60s"
}

variable "max_connections" {
  description = "The parameter specifies the maximal number of concurrent connections that will be sent to this server"
  default = "250"
}

variable "max_queue" {
  description = "The parameter specifies the maximal number of connections which will wait in the queue for this server"
  default = "256"
}
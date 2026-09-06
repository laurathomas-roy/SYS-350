# main.tf - Your first Terraform configuration

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

variable "host_port" {
  description = "Port on the host"
  type        = number
  default     = 8080
}

resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_network" "lan" {
  name = "sys350-lan"
}

resource "docker_volume" "web_data" {
  name = "nginx-html"
}

resource "docker_container" "web_server" {
  name  = "web-server"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.host_port
  }

  networks_advanced {
    name = docker_network.lan.name
  }

  volumes {
    volume_name    = docker_volume.web_data.name
    container_path = "/usr/share/nginx/html"
    read_only      = false
  }
}

output "container_ip" {
  value = docker_container.web_server.network_data[0].ip_address
}

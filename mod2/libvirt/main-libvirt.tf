# Complete libvirt stack - replaces Module 1 manual KVM commands

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "vm_memory" {
  description = "VM memory in KiB"
  type        = number
  default     = 1048576  # 1 GB
}

variable "vm_vcpu" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 4
}

# Network (replaces virsh net-define lan.xml + virsh net-start lan)
resource "libvirt_network" "lan" {
  name      = "lan"
  autostart = true

  forward = {
    mode = "nat"
  }

  ips = [
    {
      address = "192.168.100.1"
      prefix  = 24
      family  = "ipv4"

      dhcp = {
        ranges = [
          {
            start = "192.168.100.100"
            end   = "192.168.100.254"
          }
        ]
      }
    }
  ]
}

# Storage pool (replaces virsh pool-define-as default dir /var/lib/libvirt/images)
resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  target = {
    path = "/var/lib/libvirt/images"
  }
}







# VM disk (replaces virt-install --disk)
resource "libvirt_volume" "ubuntu_disk" {
  name     = "ubuntu-server.qcow2"
  pool     = "default"
  capacity = 40 * 1024 * 1024 * 1024  # 40 GB
  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    }
    format = {
      type = "qcow2"
    }
  }

  # Ensure the pool is created
  depends_on = [libvirt_pool.default]
}

# VM domain (replaces virt-install + virsh define)
resource "libvirt_domain" "ubuntu_server" {
  name   = "ubuntu-server"
  memory = var.vm_memory
  vcpu   = var.vm_vcpu
  type   = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = "default"
            volume = libvirt_volume.ubuntu_disk.name
          }
        }
        target = {
          bus  = "virtio"
          dev = "vda"
        }
        driver = {
          type = "qcow2"
        }
      }
    ]

    interfaces = [
      {
        type  = "network"
        model = { type = "virtio" }
        source = {
          network = {
            network = libvirt_network.lan.name
          }
        }
      }
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]
  }

  running = true
}

output "network_address" {
  value = "Network '${libvirt_network.lan.name}' CIDR: 192.168.100.0/24, Gateway: 192.168.100.1"
}

output "vm_name" {
  value = libvirt_domain.ubuntu_server.name
}

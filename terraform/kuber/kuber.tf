locals {
  cloud_id    = "b1gn6k9ttvc232iga77e"
  folder_id   = "b1gm6apq5aonai4olued"
  k8s_version = "1.23"
  sa_name     = "konstantin"
}


terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  folder_id = local.folder_id
}

resource "yandex_kubernetes_cluster" "terraform-cluster" {
 name = "terraform-cluster"
 description = "cluster apply from terraform"
 network_id = yandex_vpc_network.terraform_cluster_network.id
 master {
   zonal {
     zone      = yandex_vpc_subnet.terraform_cluster_subnetwork.zone
     subnet_id = yandex_vpc_subnet.terraform_cluster_subnetwork.id
   }
   public_ip = true
 }
 service_account_id      = "ajeuc61f8s9jos33mcda"
 node_service_account_id = "ajeuc61f8s9jos33mcda"
}

resource "yandex_vpc_network" "terraform_cluster_network" { name = "terraform_cluster_network" }

resource "yandex_vpc_subnet" "terraform_cluster_subnetwork" {
 v4_cidr_blocks = ["10.2.0.0/16"]
 zone           = "ru-central1-b"
 network_id     = yandex_vpc_network.terraform_cluster_network.id
}


resource "yandex_kubernetes_node_group" "terraform-group" {
  cluster_id = yandex_kubernetes_cluster.terraform-cluster.id
  name       = "terraform-group"
  instance_template {
    name       = "terraform-vm-{instance.index}"
    platform_id = "standard-v1"
    container_runtime {
     type = "containerd"
    }
    resources {
      memory = 4
      cores  = 2
    }
    boot_disk {
      size = 50
    }
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
}
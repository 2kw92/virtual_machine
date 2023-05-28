locals {
  cloud_id    = "b1gn6k9ttvc232iga77e"
  folder_id   = "b1gm6apq5aonai4olued"
  k8s_version = "1.24"
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
    version = local.k8s_version
    zonal {
      zone      = yandex_vpc_subnet.terraform_cluster_subnetwork.zone
      subnet_id = yandex_vpc_subnet.terraform_cluster_subnetwork.id
    }
    public_ip = true
    security_group_ids = [
      yandex_vpc_security_group.k8s-master-whitelist.id,
      yandex_vpc_security_group.k8s-main-sg.id
    ]
  }
  service_account_id      = "ajeuc61f8s9jos33mcda"
  node_service_account_id = "ajeuc61f8s9jos33mcda"
}

resource "yandex_vpc_network" "terraform_cluster_network" { name = "terraform_cluster_network" }

resource "yandex_vpc_subnet" "terraform_cluster_subnetwork" {
 name = "terraform_cluster_subnetwork"
 v4_cidr_blocks = ["10.2.0.0/16"]
 zone           = "ru-central1-b"
 network_id     = yandex_vpc_network.terraform_cluster_network.id
}


resource "yandex_kubernetes_node_group" "terraform-group" {
  cluster_id = yandex_kubernetes_cluster.terraform-cluster.id
  name       = "terraform-group"
  instance_template {
    name       = "terraform-vm-{instance.index}"
    platform_id = "standard-v2"
    network_interface {
      nat = true
      subnet_ids         = [yandex_vpc_subnet.terraform_cluster_subnetwork.id]
      security_group_ids = [
        yandex_vpc_security_group.k8s-public-services.id,
        yandex_vpc_security_group.k8s-main-sg.id
      ]
    }
    container_runtime {
     type = "containerd"
    }
    resources {
      memory = 8
      cores  = 4
    }
    boot_disk {
      size = 30
    }
  }
  scale_policy {
    fixed_scale {
      size = 4
    }
  }
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  name        = "k8s-main-sg"
  description = "Правила группы обеспечивают базовую работоспособность кластера. Примените ее к кластеру и группам узлов."
  network_id  = yandex_vpc_network.terraform_cluster_network.id
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol       = "ANY"
    description    = "Правило разрешает взаимодействие под-под и сервис-сервис. Укажите подсети вашего кластера и сервисов."
    v4_cidr_blocks = ["10.2.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }
  ingress {
    protocol       = "ICMP"
    description    = "Правило разрешает отладочные ICMP-пакеты из внутренних подсетей."
    v4_cidr_blocks = ["172.16.0.0/12", "10.0.0.0/8", "192.168.0.0/16"]
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  name        = "k8s-public-services"
  description = "Правила группы разрешают подключение к сервисам из интернета. Примените правила только для групп узлов."
  network_id  = yandex_vpc_network.terraform_cluster_network.id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort. Добавьте или измените порты на нужные вам."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "k8s-master-whitelist" {
  name        = "k8s-master-whitelist"
  description = "Правила группы разрешают доступ к API Kubernetes из интернета. Примените правила только к кластеру."
  network_id  = yandex_vpc_network.terraform_cluster_network.id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 6443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
}

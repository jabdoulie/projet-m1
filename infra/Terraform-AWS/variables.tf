variable "aws_region" {
  description = "La région AWS dans laquelle déployer les ressources"
  type        = string
  default     = "eu-west-3" # Par défaut, la région est 'eu-west-3'
}

variable "instance_count" {
  description = "Le nombre d'instances à créer"
  type        = number
  default     = 1 # Par défaut, 1 instance sera créée. Modifiez selon vos besoins.
}

variable "instance_type" {
  description = "Type EC2 (t3.medium = 4 Go RAM, adapté à MicroK8s ; t2.micro insuffisant pour 2 nœuds K8s)"
  type        = string
  default     = "t3.medium"
}

variable "default_root_volume_size" {
  description = "Taille du volume root EBS (Go) si l'instance n'est pas dans instance_root_volume_sizes"
  type        = number
  default     = 20
}

variable "instance_root_volume_sizes" {
  description = "Taille du disque root par rôle (Go). L'AMI Ubuntu par défaut ne fournit que ~8 Go — insuffisant pour MicroK8s + Flux + images Docker"
  type        = map(number)
  default = {
    Frontend   = 30
    Backend    = 20
    Database   = 20
    Monitoring = 25
  }
}

variable "root_volume_type" {
  description = "Type de volume EBS root (gp3 recommandé)"
  type        = string
  default     = "gp3"
}

variable "instance_names" {
  description = "Les noms des instances à créer"
  type        = list(string)
  default     = ["Frontend", "Backend", "Database", "Monitoring"]
}

variable "instance_ports" {
  description = "Ports à ouvrir par instance"
  type = map(list(object({
    port        = number
    protocol    = string
    description = string
  })))
  default = {
    "Frontend" = [
      { port = 22, protocol = "tcp", description = "SSH" },
      { port = 80, protocol = "tcp", description = "HTTP" },
      { port = 443, protocol = "tcp", description = "HTTPS" },
      { port = 9100, protocol = "tcp", description = "node_exporter" }
    ]
    "Backend" = [
      { port = 22, protocol = "tcp", description = "SSH" },
      { port = 9000, protocol = "tcp", description = "PHP-FPM" },
      { port = 9100, protocol = "tcp", description = "node_exporter" }
    ]
    "Database" = [
      { port = 22, protocol = "tcp", description = "SSH" },
      { port = 3306, protocol = "tcp", description = "MySQL" },
      { port = 6379, protocol = "tcp", description = "Redis" },
      { port = 9100, protocol = "tcp", description = "node_exporter" }
    ]
    "Monitoring" = [
      { port = 22, protocol = "tcp", description = "SSH" },
      { port = 3000, protocol = "tcp", description = "Grafana" },
      { port = 9090, protocol = "tcp", description = "Prometheus" },
      { port = 3100, protocol = "tcp", description = "Loki" },
      { port = 9100, protocol = "tcp", description = "node_exporter" }
    ]
  }
}

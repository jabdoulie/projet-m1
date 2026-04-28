terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Utilise le profil AWS configuré, ou les variables d'environnement si non spécifié
  # Pour utiliser un profil spécifique, décommenter la ligne suivante :
  # profile = "default"
  
  # Ou configurer via variables d'environnement :
  # export AWS_ACCESS_KEY_ID="your-access-key"
  # export AWS_SECRET_ACCESS_KEY="your-secret-key"
}

# Projet M1 — Wave, AWS, GitOps et observabilité

Monorepo pour une application **Wave** (Laravel / SaaS), déployée sur **Amazon Web Services** avec **Terraform**, configurée par **Ansible**, livrée en **GitOps** avec **FluxCD**, et analysée en **CI/CD** via **GitHub Actions** et **SonarCloud**.

## Architecture cible

| Rôle | Contenu principal |
|------|-------------------|
| **Frontend** | MicroK8s, FluxCD (contrôleur GitOps), charge applicative exposée (Nginx / ingress) |
| **Backend** | MicroK8s, workloads applicatifs (PHP-FPM) |
| **Database** | MySQL et Redis via Docker Compose |
| **Monitoring** | Prometheus, Loki, Grafana (Docker Compose) ; métriques **node_exporter** et logs **Promtail** sur chaque serveur |

La **CI/CD** ne repose plus sur une VM Jenkins : les pipelines sont dans **`.github/workflows/`** (workflow réutilisable aligné sur l’ancien `Jenkinsfile`).

## Arborescence utile

- **`wave-app/`** — code Laravel Wave, `Dockerfile`, manifests Kubernetes (`k8s/`), `sonar-project.properties` pour SonarCloud.
- **`infra/Terraform-AWS/`** — VPC, sous-réseau, groupes de sécurité, EC2, clés SSH, génération de l’inventaire Ansible.
- **`infra/Ansible/`** — playbooks (Docker, base de données, monitoring, agents, MicroK8s, FluxCD).
- **`.github/workflows/`** — `ci.yml` appelle `reusable-wave-ci.yml` (tests, Trivy, SonarCloud, build/push image, mise à jour du manifeste K8s sur `main`).

## Démarrage rapide

1. **Infrastructure** : depuis `infra/Terraform-AWS`, exécuter `terraform init`, `terraform plan`, `terraform apply` (credentials AWS profil `default`, région par défaut `eu-west-3`).
2. **Configuration des serveurs** : depuis `infra/Ansible`, utiliser l’`inventory.ini` généré par Terraform sous `../Ansible/inventory.ini`, puis `ansible-playbook -i inventory.ini playbook.yml`.
3. **CI/CD** : dans GitHub — *Settings → Secrets and variables → Actions* — définir au minimum `DOCKER_IMAGE`, `DOCKER_USERNAME`, `DOCKER_PASSWORD` pour le déploiement d’image sur `main` ; `SONAR_TOKEN` pour SonarCloud (optionnel).

Détails des variables Terraform, des secrets GitHub et des playbooks : **`infra/README.md`**.

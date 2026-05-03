# Infrastructure — Terraform et Ansible

Ce répertoire décrit le déploiement des machines **AWS** et leur configuration avec **Ansible**. La chaîne **CI/CD applicative** (tests, analyse, image Docker, bump du manifeste Kubernetes) est assurée par **GitHub Actions** à la racine du dépôt, pas par une VM Jenkins.

## Terraform (`Terraform-AWS/`)

- **Rôle** : création d’un VPC (CIDR `10.123.0.0/16`), sous-réseau public, passerelle Internet, **4 instances EC2** nommées `Frontend`, `Backend`, `Database`, `Monitoring`.
- **Type d’instance** : variable `instance_type` (défaut `t3.medium`, ~4 Go RAM) pour supporter MicroK8s.
- **Clés SSH** : une paire par instance, fichiers privés écrits dans `Ansible/keys/` (hors commit recommandé).
- **Groupes de sécurité** : ports ouverts selon `variables.tf` (SSH, services applicatifs, Grafana 3000, Prometheus 9090, Loki 3100, node_exporter 9100, etc.).
- **Inventaire Ansible** : ressource `local_file` qui génère `../Ansible/inventory.ini` avec les IP publiques et les chemins de clés.

Commandes typiques :

```bash
cd infra/Terraform-AWS
terraform init
terraform plan
terraform apply
```

Provider AWS : profil **`default`** (`providers.tf`). Adapter la région avec `var.aws_region` si besoin.

## Ansible (`Ansible/`)

Exécution depuis **`infra/Ansible`** pour que les chemins relatifs (`./keys/`, etc.) correspondent à l’inventaire Terraform.

| Fichier | Rôle |
|---------|------|
| `playbook.yml` | Orchestration principale |
| `playbook-database.yml` | MySQL + Redis (Docker Compose) |
| `playbook-monitoring.yml` | Prometheus + Loki + Grafana |
| `playbook-observability-agents.yml` | node_exporter + Promtail sur tous les serveurs |
| `playbook-microk8s.yml` | MicroK8s sur Frontend et Backend |
| `playbook-fluxcd.yml` | FluxCD sur le groupe `frontend` |
| `ansible.cfg` | Exemple : désactivation stricte des host keys pour les tests (lab) |

Groupes d’inventaire attendus : `frontend`, `backend`, `database`, `monitoring`, `webservers` (frontend + backend), `serveurs` (les quatre machines).

## CI/CD (racine du dépôt)

- **`.github/workflows/ci.yml`** : déclencheur sur `main` (push / PR), appelle le workflow réutilisable, ignore les pushes dont le message contient `[skip ci]` (évite la boucle après le commit GitOps).
- **`.github/workflows/reusable-wave-ci.yml`** : équivalent fonctionnel de l’ancien `Jenkinsfile` (Composer, Pest, Trivy FS sur la racine, SonarCloud, build/push Docker sur push `main`, `sed` sur `wave-app/k8s/deployment.yml`, commit poussé par `github-actions`).

Secrets dépôt utiles : `SONAR_TOKEN`, `DOCKER_IMAGE`, `DOCKER_USERNAME`, `DOCKER_PASSWORD`. SonarCloud : fichier `wave-app/sonar-project.properties` (notamment `sonar.organization`).

## Fichiers Docker Compose côté Ansible

- `docker-compose.database.yml` — base de données.
- `docker-compose.monitoring.yml` — stack observabilité sur la VM monitoring.
- `docker-compose.agents.yml` — node_exporter + Promtail sur chaque hôte.
- `docker-compose.yml` (racine Ansible) — ancien stack Jenkins/Sonar **self-hosted** ; non utilisé par le `playbook.yml` actuel. Conservé seulement si vous réutilisez Jenkins en local.

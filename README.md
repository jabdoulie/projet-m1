# Projet M1 — Wave, AWS, GitOps et observabilité

Monorepo pour une application **Wave** (Laravel / SaaS), déployée sur **Amazon Web Services** avec **Terraform**, configurée par **Ansible**, livrée en **GitOps** avec **FluxCD**, et analysée en **CI/CD** via **GitHub Actions** et **SonarCloud**.

## Architecture

| VM (Terraform) | Rôle |
|----------------|------|
| **Frontend** | MicroK8s, FluxCD, Ingress Traefik, pods `wave-app` (PHP-FPM) + `wave-nginx` |
| **Backend** | MicroK8s (cluster séparé, prévu pour workloads additionnels) |
| **Database** | MySQL 8 + Redis 7 (Docker Compose) |
| **Monitoring** | Prometheus, Loki, Grafana (Docker Compose) ; **node_exporter** + **Promtail** sur chaque serveur |

Le trafic utilisateur arrive sur le **Frontend** (ports 80/443) → Ingress → Nginx → PHP-FPM. MySQL et Redis sont **externes au cluster** (IP privée VPC de la VM Database, ex. `10.123.1.11`).

La **CI/CD** est dans **`.github/workflows/`** (plus de VM Jenkins).

## Arborescence

| Chemin | Contenu |
|--------|---------|
| `wave-app/` | Code Laravel Wave, `Dockerfile`, `entrypoint.sh`, manifests K8s (`k8s/`), SonarCloud |
| `infra/Terraform-AWS/` | VPC, EC2, security groups, inventaire Ansible |
| `infra/Ansible/` | Playbooks (Docker, DB, monitoring, MicroK8s, FluxCD) |
| `infra/flux/` | Sources FluxCD (GitRepository, Kustomization) |
| `.github/workflows/` | Tests, Trivy, SonarCloud, build/push Docker, bump image sur `main` |

## Démarrage infrastructure

1. **Terraform** (`infra/Terraform-AWS`) : `terraform init`, `plan`, `apply` (profil AWS `default`, région `eu-west-3` par défaut).
2. **Ansible** (`infra/Ansible`) : `ansible-playbook -i inventory.ini playbook.yml` (inventaire généré par Terraform).
3. **Secrets GitHub** (*Settings → Secrets and variables → Actions*) : `DOCKER_IMAGE`, `DOCKER_USERNAME`, `DOCKER_PASSWORD`, `SONAR_TOKEN` (optionnel).

Détails : **`infra/README.md`**.

## Accès à l'application

### Prérequis navigateur

Ajouter dans le fichier **hosts** de votre machine :

```text
<IP_PUBLIQUE_FRONTEND>  wave.local
```

Exemple Windows : `C:\Windows\System32\drivers\etc\hosts` — Linux/Mac : `/etc/hosts`.

> N'utilisez pas l'IP seule dans le navigateur : l'Ingress répond au nom d'hôte **`wave.local`**.

### URLs

| Protocole | URL | Certificat |
|-----------|-----|------------|
| HTTP | `http://wave.local` | — |
| HTTPS (lab) | `https://wave.local` | Auto-signé (`wave-tls-secret`) — avertissement navigateur normal |

### Compte admin par défaut (après seed)

- **Email** : `admin@admin.com`
- **Mot de passe** : `password`

## Déploiement applicatif (GitOps)

Sur push vers `main` (si `ENABLE_DEPLOY` et secrets Docker configurés) :

1. GitHub Actions : tests, SonarCloud, Trivy, build/push image Docker (`abdoulie/wave-image:N`).
2. Commit automatique du tag d'image dans `wave-app/k8s/deployment.yml` (`[skip ci]`).
3. FluxCD sur le Frontend détecte le changement et applique `wave-app/k8s/`.

Commandes utiles sur la VM **Frontend** :

```bash
flux reconcile kustomization wave-app --with-source
microk8s kubectl get pods -n wave
microk8s kubectl rollout restart deployment -n wave wave-app wave-nginx
microk8s kubectl logs -n wave -l app=wave-app --tail=50
```

## HTTPS sans avertissement navigateur

Le certificat auto-signé de `wave.local` convient au **lab** uniquement. Pour un cadenas valide en production :

1. Obtenir un **vrai domaine** (ex. `wave.mondomaine.com`).
2. Enregistrement DNS **A** → IP publique du Frontend.
3. Activer **cert-manager** sur MicroK8s (`microk8s enable cert-manager`).
4. Configurer un **ClusterIssuer Let's Encrypt** et adapter l'Ingress + `APP_URL` dans `wave-app/k8s/wave-env.yml`.

Let's Encrypt ne délivre pas de certificat pour `wave.local`.

## Configuration Kubernetes (`wave-app/k8s/`)

| Fichier | Rôle |
|---------|------|
| `wave-env.yml` | ConfigMap (DB, Redis, `APP_URL`, cache) |
| `wave-secrets.yml` | Mots de passe, `APP_KEY` |
| `deployment.yml` | `wave-app` + `wave-nginx`, image Docker |
| `ingress.yml` | Exposition `wave.local` (HTTP + TLS) |
| `wave-nginx-config.yml` | Nginx Alpine, healthcheck `/healthz` |

**Base de données** : mettre à jour `DB_HOST` et `REDIS_HOST` dans `wave-env.yml` avec l'IP **privée** de la VM Database (après `terraform apply`, l'IP peut changer).

## Dépannage fréquent

| Symptôme | Cause probable |
|----------|----------------|
| 404 avec l'IP publique | Accès sans `Host: wave.local` — utiliser `/etc/hosts` |
| Page blanche, HTML vide | Base MySQL incomplète — `php artisan migrate:fresh --seed --force` dans le pod |
| Pod `wave-app` en boucle | Mauvais `DB_HOST` ou mot de passe — vérifier `wave-env` / `wave-secrets` |
| `disk-pressure` sur MicroK8s | Volume root trop petit — augmenter EBS dans Terraform (Frontend ≥ 30 Go) |

## CI/CD

- **`.github/workflows/ci.yml`** : déclencheur `main`, permissions `contents: write` pour le commit GitOps.
- **`.github/workflows/reusable-wave-ci.yml`** : pipeline complet (équivalent de l'ancien `Jenkinsfile`).

Variable de workflow : `ENABLE_DEPLOY: "true"` pour activer build et déploiement image.

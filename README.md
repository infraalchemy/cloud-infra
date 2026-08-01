# Moodle Infrastructure Project

### Docker • Kubernetes • Terraform • Google Cloud

Moodle was selected because it represents a realistic, stateful application with multiple moving parts. It requires application configuration, database persistence, storage management, networking, and deployment automation.

This repository documents my journey deploying the same application across different environments. I started with Docker Compose on a Google Cloud VM, migrated the workload into a local Kubernetes cluster using KinD, and began exploring infrastructure provisioning with Terraform. Future work includes GitHub Actions integration and Google Cloud authentication using Workload Identity Federation.

---

## Repository Structure

```text
├── .github/                              # GitHub Actions workflows
│
├── docs/                                 # Engineering documentation
│   ├── gcp_terraform_deploy.md           # GCP VM/infrastructure provisioning guide
│   ├── p1_docker_deploy.md               # docker-compose deployment guide
│   ├── p1_post_mortem.md                 # docker-compose troubleshooting notes
│   ├── p2_k8_deploy.md                   # Kubernetes KinD deployment guide
│   └── p2_post_mortem.md                 # Kubernetes troubleshooting notes
│
├── docker/                               # docker-compose deployment
│   ├── docker-compose.yml                # Moodle multi-container application stack
│   ├── moodledata/                       # Persistent Moodle application data
│   ├── mysql/                            # MySQL database configuration
│   │   └── mysql-data/                   # Persistent MySQL database storage
│   ├── nginx/                            # Nginx reverse proxy container
│   │   ├── Dockerfile                    # Custom Nginx image definition
│   │   └── nginx.conf                    # Nginx configuration
│   └── php/                              # PHP-FPM Moodle application container
│       ├── Dockerfile                    # Custom PHP runtime image
│       ├── entrypoint.sh                 # Container initialization script
│       ├── index.php                     # PHP validation entry point
│       └── testdb.php                    # Database connectivity test
│
├── kubernetes/                           # Kubernetes application manifests
│   ├── mysql/                            # MySQL database deployment
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── nginx/                            # Nginx reverse proxy deployment
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── php/                              # PHP-FPM Moodle application deployment
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   ├── storage/                          # Persistent Moodle storage
│   │   └── moodle-storage.yaml
│   │
│   └── overlays/                         # Environment-specific configuration
│       ├── local-kind/                   # Local KinD Kubernetes environment
│       │   ├── ingress.yaml
│       │   ├── kind-config.yaml
│       │   └── kustomization.yaml
│       │
│       └── prod-gcp/                     # Planned GKE deployment
│
├── terraform/                            # Google Cloud infrastructure provisioning
│   ├── modules/                          # Reusable Terraform modules
│   │   ├── gke/                          # Planned GKE resources
│   │   └── vpc/                          # Planned VPC networking resources
│   ├── main.tf                           # Terraform entry point
│   ├── outputs.tf                        # Terraform outputs
│   └── variables.tf                      # Terraform variables
│
├── Dockerfile                            # Root Moodle application image build
├── README.md
└── .gitignore
```

## Project Documentation


To keep the repository clean and easy to navigate, the technical operational details have been separated into dedicated engineering logs:
* 📄 **[GCP Terraform Deployment Guide](./docs/gcp_terraform_deploy.md)**

* 📄 **[P1 Docker Deployment Guide](./docs/p1_docker_deploy.md)**

* 📄 **[P1 Post-Mortem](./docs/p1_post_mortem.md)**

* 📄 **[P2 Kubernetes Deployment Guide](./docs/p2_K8_deploy.md)**


To keep the repository organized, deployment guides and troubleshooting notes are maintained separately:

* 📄 **[GCP Terraform Deployment Guide](./docs/gcp_terraform_deploy.md)**
* 📄 **[P1 Docker Deployment Guide](./docs/p1_docker_deploy.md)**
* 📄 **[P1 Post-Mortem](./docs/p1_post_mortem.md)**
* 📄 **[P2 Kubernetes Deployment Guide](./docs/p2_K8_deploy.md)**
* 📄 **[P2 Kubernetes Deployment Guide](./docs/p2_k8_deploy.md)**
* 📄 **[P2 Kubernetes Post-Mortem](./docs/p2_post_mortem.md)**

---

# Cloud Infrastructure Progression: My Project Journey

Rather than building separate labs, I chose to evolve the same application through different deployment models. Each phase introduced new challenges and provided a better understanding of how infrastructure, networking, storage, and automation work together.

## Phase 1 – Containerized Moodle Deployment on GCP

### Goal
Build and run a complete Moodle stack using containerized services on cloud infrastructure.
The application was deployed on a Linux Compute Engine VM running on Google Cloud using separate containers for Nginx, PHP-FPM, and MySQL. The deployment included Docker networking, persistent storage, resource configuration, and cloud firewall integration.

### Result
Successfully deployed a working containerized Moodle environment. This provided the foundation for migrating the application into Kubernetes.

---

## Phase 2 – Local Cluster Orchestration & Debugging (Kubernetes with KinD)

### Goal
Migrate the Docker-based Moodle deployment into a local KinD Kubernetes cluster to validate container orchestration, networking, storage, ingress routing, and deployment workflows.

The application was migrated using Kubernetes resources including Deployments, Services, Persistent Volume Claims, Secrets, ConfigMaps, initContainers, and Ingress routing.

### Result
Successfully deployed the Moodle application on a multi-node KinD Kubernetes cluster within Windows 11/WSL2, confirming full web access and file-upload functionality.

---

## Phase 3 – Cloud Infrastructure Automation (Future Work)

### Goal
Expand the project to include automated infrastructure provisioning and cloud-native deployment workflows.

### Planned Work
Future enhancements include Terraform automation, GitHub Actions integration, Google Cloud Workload Identity Federation (OIDC), and evaluating migration of the Kubernetes deployment to Google Kubernetes Engine (GKE).

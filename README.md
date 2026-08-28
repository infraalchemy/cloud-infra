# Moodle Infrastructure Project

### Docker • Kubernetes • Terraform • Google Cloud

Moodle was selected because it represents a realistic, stateful application with multiple moving parts. It requires application configuration, database persistence, storage management, networking, and deployment automation.

This repository documents my journey deploying the same application across different environments. I started with Docker Compose on a Google Cloud VM, migrated the workload into a local Kubernetes cluster using KinD, and then deployed it to Google Kubernetes Engine (GKE) using Terraform and Kustomize. Future work includes GitHub Actions integration and Google Cloud authentication using Workload Identity Federation.

---

## Deployment Environment

All infrastructure provisioning and application deployments were initiated from a Windows workstation.

- Workstation: Windows
- Local Linux environment: WSL2
- Container runtime: Docker Desktop
- Local Kubernetes: KinD
- Cloud infrastructure: Google Cloud Platform (GCP)
- Cloud Kubernetes: Google Kubernetes Engine (GKE)
- Infrastructure as Code: Terraform

---

## Repository Structure

*Temporary component-level Kustomizations were used during testing to independently deploy and validate each component.*


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
├── kubernetes/                           # Kubernetes deployment configurations
│   ├── kind/                             # Local KinD Kubernetes environment
│   │   ├── storage/                      # Persistent Moodle storage
│   │   │   └── moodle-storage.yaml       # Persistent storage configuration
│   │   │
│   │   ├── mysql/                        # MySQL database
│   │   │   ├── deployment.yaml           # MySQL deployment definition
│   │   │   └── service.yaml              # Internal Kubernetes service for MySQL
│   │   │
│   │   ├── php/                          # PHP-FPM Moodle application
│   │   │   ├── deployment.yaml           # PHP-FPM application deployment
│   │   │   └── service.yaml              # Internal service exposing PHP-FPM
│   │   │
│   │   ├── nginx/                        # Nginx reverse proxy
│   │   │   ├── configmap.yaml            # Nginx configuration
│   │   │   ├── deployment.yaml           # Nginx reverse proxy deployment
│   │   │   └── service.yaml              # Internal service exposing Nginx
│   │   │
│   │   └── overlays/                     # KinD-specific configuration
│   │       ├── ingress.yaml              # Local ingress configuration
│   │       ├── kind-config.yaml          # KinD cluster and node configuration
│   │       └── kustomization.yaml        # Kustomize configuration for KinD
│   │
│   └── gcp-gke/                          # Google Kubernetes Engine environment
│       ├── storage/                      # Persistent Moodle storage
│       │   ├── moodle-storage.yaml       # PersistentVolumeClaim definitions for Moodle data
│       │   └── kustomization.yaml        # Kustomize configuration for GKE storage
│       │
│       ├── mysql/                        # MySQL database
│       │   ├── deployment.yaml           # MySQL deployment definition
│       │   ├── service.yaml              # Internal Kubernetes service for MySQL
│       │   └── kustomization.yaml        # Kustomize configuration for GKE MySQL  
│       │
│       ├── php/                          # PHP-FPM Moodle application
│       │   ├── deployment.yaml           # PHP-FPM application deployment
│       │   ├── service.yaml              # Internal service exposing PHP-FPM
│       │   └── kustomization.yaml        # Kustomize configuration for GKE PHP   
│       │
│       ├── nginx/                        # Nginx reverse proxy
│       │   ├── configmap.yaml            # Nginx configuration
│       │   ├── deployment.yaml           # Nginx reverse proxy deployment
│       │   ├── service.yaml              # Internal service exposing Nginx
│       │   ├── backendconfig.yaml        # GKE load balancer health-check configuration
│       │   └── kustomization.yaml        # Kustomize configuration for GKE Nginx  
│       │
│       └── overlays/                     # GKE-level configuration
│           ├── ingress.yaml              # GKE Ingress configuration for external access
│           ├── kustomization.yaml        # Kustomize configuration for GKE Ingress  
│           └── managed-cert.yaml         # Google-managed SSL/TLS certificate
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
├── README.md                             # Project overview and deployment documentation
└── .gitignore                            # Git ignore rules

```

---

## Project Documentation

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

## Phase 2 – Local Moodle Kubernetes Cluster (KinD)

### Goal
Migrate the Docker-based Moodle deployment into a local KinD Kubernetes cluster to validate container orchestration, networking, storage, ingress routing, and deployment workflows.

The application was migrated using Kubernetes resources including Deployments, Services, Persistent Volume Claims, Secrets, ConfigMaps, initContainers, and Ingress routing.

### Result
Successfully deployed the Moodle application on a multi-node KinD Kubernetes cluster within Windows 11/WSL2, confirming full web access and file-upload functionality.

---

## Phase 3 – Moodle Kubernetes Deployment on GKE
*Recreate testing and documentation in progress*

### Goal
Migrate the Kubernetes-based Moodle deployment from the local KinD environment to Google Kubernetes Engine (GKE) to validate cloud infrastructure provisioning, persistent storage, ingress routing, SSL, and environment-specific deployment workflows.

The application was deployed using Kubernetes resources including Deployments, Services, Persistent Volume Claims, Secrets, ConfigMaps, initContainers, and GKE Ingress routing. Infrastructure and environment configuration were managed using Terraform and Kustomize.

### Result
Successfully deployed the Moodle application on a multi-node GKE cluster with persistent RWX/Filestore storage, GKE Ingress, a global static IP, and Google-managed HTTPS certificates for secure external access. The deployment uses separate Kubernetes components for MySQL, PHP, Nginx, and persistent storage, with Terraform and Kustomize supporting repeatable infrastructure and environment-specific configuration.

### Next Steps
Integrate GitHub Actions CI/CD pipelines and implement Google Cloud Workload Identity Federation (OIDC) for secure, passwordless authentication.

---

## Phase 4 – Moodle Kubernetes Deployment on AWS

### Goal
Extend the platform to AWS to demonstrate cloud portability and the ability to apply the same infrastructure and Kubernetes deployment patterns across cloud providers.

### Planned Work
Future enhancements include Terraform-based AWS infrastructure provisioning, deployment of the Kubernetes application to Amazon Elastic Kubernetes Service (EKS), AWS identity and access management, and integration with AWS-native networking, storage, and monitoring services.


# Moodle Infrastructure Project
Moodle was selected as the application workload because it represents a realistic stateful, multi-tier platform requiring application runtime configuration, database persistence, storage management, and network routing.


### Docker • Kubernetes • Terraform • Google Cloud

Moodle was selected as the application workload because it represents a realistic stateful, multi-tier platform requiring application runtime configuration, database persistence, storage management, networking, and deployment automation.

This repository documents the evolution of a Moodle deployment from Docker Compose running on Google Cloud Compute Engine to a local Kubernetes cluster using KinD. Additional exploration includes Terraform infrastructure provisioning and GitHub Actions authentication with Google Cloud as future automation capabilities.


## Repository Structure

```text
├── .github/                              # GitHub Actions workflows
│
├── docs/                                 # Engineering documentation
│   ├── gcp_terraform_deploy.md           # GCP VM/infrastructure provisioning guide
│   ├── p1_docker_deploy.md               # docker-compose deployment guide
│   ├── p1_post_mortem.md                 # docker-compose troubleshooting notes
│   ├── p2_kubernetes_deploy.md           # Kubernetes KinD deployment guide
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

* 📄 **[P2 Kubernetes Post-Mortem](./docs/p2_post_mortem.md)**

---

# Cloud Infrastructure Progression: My Project Journey

This project follows the evolution of the same Moodle application through increasing levels of infrastructure complexity. Rather than building isolated labs, I chose to evolve the same application through multiple deployment models, solving real infrastructure problems along the way.

## Phase 1 – Virtual Cloud Instances & Container Networking (docker-compose to GCP VM)
### Goal
Build and run a complete Moodle stack using containerized services on cloud infrastructure.
### Architecture & Implementation
I began by containerizing the core application layers and managing them as isolated workloads (Nginx, PHP-FPM, MySQL) on a single virtual host interface. The stack was deployed on a Linux Compute Engine VM running on Google Cloud. 
### Results & Skills Mastered
Built and deployed a working containerized Moodle environment with isolated Docker networking, persistent storage, resource configuration, and cloud firewall integration. This established the foundation for migration into Kubernetes.


## Phase 2 – Local Cluster Orchestration & Debugging (Kubernetes with KinD)
### Goal
Migrate the Docker-based Moodle deployment into a local KinD Kubernetes cluster to implement and validate container orchestration, networking, ingress routing, storage, and application deployment workflows before moving to the cloud.
### Architecture & Implementation
The Docker-based Moodle deployment was migrated into Kubernetes by combining custom container images with declarative Kubernetes objects (Deployments, ClusterIP Services, Persistent Volume Claims, Secrets, ConfigMaps, initContainers, and Ingress routing rules). 
### Results & Skills Mastered
Successfully deployed Moodle as a multi-tier Kubernetes application running locally on KinD within Windows 11/WSL2. Operating locally exposed a number of Windows, Docker, and Kubernetes integration edge cases that required detailed troubleshooting. I diagnosed and resolved core engineering bottlenecks, including cross-container network locks, proxy timeout limits, and ingress-to-node scheduling dependencies.


## Phase 3 – Cloud Infrastructure Automation (Future Work)

### Goal

Extend the application deployment model with automated infrastructure provisioning and cloud deployment workflows.

### Planned Architecture & Automation

Future work includes expanding Terraform infrastructure automation, integrating GitHub Actions workflows, using Google Cloud Workload Identity Federation (OIDC) for keyless authentication, and evaluating migration of the Kubernetes deployment to Google Kubernetes Engine (GKE).

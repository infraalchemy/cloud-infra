# GCP Terraform Deployment Guide

This guide covers authenticating with GCP, provisioning infrastructure with Terraform, and deploying your application containers via Docker Compose.

---

# Prerequisites

This project provisions a Google Cloud Compute Engine virtual machine using Terraform and deploys the application using docker-compose.

Required software:

- Windows host
- Git Bash terminal
- Google Cloud SDK (gcloud CLI)
- Terraform
- Git

Verify installations:

```bash
gcloud --version
terraform --version
git --version
```

---

# Deployment Workflow

The deployment follows this simplified, automated sequence:

1. Authenticate Google Cloud CLI
2. Configure Application Default Credentials
3. Configure target Google Cloud project
4. Verify required IAM permissions
5. Link project billing and enable required Google Cloud APIs
6. Execute the integrated automation script (`./deploy.sh`)

---

# Google Cloud Authentication

Authenticate the Google Cloud account:
```bash
gcloud auth login
```

Configure Application Default Credentials:
```bash
gcloud auth application-default login
```

Verify the active account:
```bash
gcloud config list account
```

Expected:
```text
[core]
account = <your-email-address>
```

---

## Project Configuration

Clear out sticky terminal memory overrides from legacy sessions:
```bash
unset CLOUDSDK_CORE_PROJECT
unset GOOGLE_PROJECT
```

Set the target Google Cloud project:
```bash
export PROJECT_ID="<YOUR_GCP_PROJECT_ID>"

gcloud config set project $PROJECT_ID
export GOOGLE_PROJECT="$PROJECT_ID"
export CLOUDSDK_CORE_PROJECT="$PROJECT_ID"
```

Updates are available for some Google Cloud CLI components.
```bash
gcloud components update
```

Verify the active project:
```bash
gcloud config list project
```

Expected:
```text
[core]
project = <YOUR_GCP_PROJECT_ID>
```

Configure Application Default Credentials quota project:
```bash
gcloud auth application-default set-quota-project $PROJECT_ID
```

---

# Identity & Access Management (IAM) Configuration

Elevate network management rights on your developer profile to allow firewall creation:
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:<YOUR_EMAIL_ADDRESS>" \
    --role="roles/compute.admin"
```

*Note: Refresh local credentials immediately after role assignment to apply the new permissions:*

```bash
gcloud auth application-default login
```

---

# Required Google Cloud APIs & Billing Alignment

Link your active billing account to prevent project suspension when exposing network rules:
```bash
gcloud billing projects link $PROJECT_ID --billing-account=<YOUR_BILLING_ACCOUNT_ID>
```

Enable the Google Cloud APIs required for Terraform infrastructure provisioning (execute sequentially to prevent string parsing errors):
```bash
gcloud services enable compute.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

---

# Terraform Infrastructure Deployment

Initialize Terraform and pull the required provider binaries:
```bash
terraform init
```

Generate the infrastructure plan and verify it maps out `2 to add`:
```bash
terraform plan
```

Deploy the infrastructure using the automation wrapper script:
```bash
./deploy.sh
```

Creates:
- Compute Engine VM
- Firewall rules
- Network configuration

Verify Terraform output variables:
```bash
terraform output
```

Expected:
```text
vm_ip = "<external-vm-ip>"
```

---

# Application Access and Workload Verification

Establish an SSH connection to the newly provisioned Compute Engine instance:
```bash
gcloud compute ssh moodle-vm --zone=<YOUR_GCP_ZONE>
```

Verify that the automation setup successfully initialized Docker and spun up the Moodle containers:
```bash
docker compose ps
```

Expected output:
```text
NAME          IMAGE          COMMAND                  SERVICE   STATUS    PORTS
moodle-db     mysql:8.0      "docker-entrypoint.s…"   db        running   3306/tcp
moodle-web    nginx:alpine   "/docker-entrypoint.…"   web       running   0.0.0.0:80->80/tcp
moodle-app    php:8.2-fpm    "docker-php-entrypoi…"   app       running   9000/tcp
```

---

# Public Access Verification

Extract the public IP address from the Terraform outputs and test network routing via your browser:
```text
http://<external-vm-ip>
```

Expected result:
- The Moodle configuration entry point loads instantly.
- Cloud firewall rules correctly allow and route incoming traffic on port 80.
- End-to-end containerized database and runtime persistence function properly.

---

# Destroy Environment

To avoid ongoing cloud consumption and billing charges, tear down all provisioned resources cleanly via Terraform:
```bash
terraform destroy --auto-approve
```

This successfully removes:
* The Compute Engine virtual machine instance.
* Custom cloud firewall rules and dedicated VPC network overrides.
* Attached external IP allocations and volatile disk mounts.

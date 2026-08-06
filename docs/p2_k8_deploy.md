# Phase 2 Deployment Runbook: Local Kubernetes Deployment with KinD

This guide documents the complete process used to build, deploy, validate, and rebuild a local containerized Moodle environment. The entire architecture runs within a local multi node Kubernetes cluster provisioned via KinD.

---

# Prerequisites

This project deploys a local Kubernetes environment using KinD.

Required software:

- Windows host
- Docker Desktop with WSL2 backend enabled
- KinD
- kubectl
- Git

Verify installations:
```bash
docker --version
kind --version
kubectl version --client
git --version
```

---

# Deployment Workflow

The deployment follows this sequence:

1. Create KinD cluster
2. Deploy persistent storage
3. Deploy MySQL database
4. Build and deploy custom PHP/Moodle application image
5. Deploy Nginx web server
6. Configure Ingress routing
7. Verify localhost access and complete Moodle setup
8. Verify application lifecycle and persistence

---

# KinD Cluster Setup

Use when recreating the environment from a clean state.
```bash
kind delete cluster --name lab
```

Verify the cluster has been removed:
```bash
kind get clusters
```

Optional check for leftover KinD containers:
```bash
docker ps -a | grep kind
```

---

## Create Cluster

Create the local KinD cluster:

```bash
kind create cluster \
  --config kubernetes/overlays/local-kind/kind-config.yaml \
  --name lab
```

Configure kubectl context:
```bash
kind export kubeconfig --name lab
```

Expected context:
```text
Set kubectl context to "kind-lab"
```

Verify cluster nodes:
```bash
kubectl get nodes
```

Expected result:
```text
lab-control-plane
lab-worker
```

---

# Storage Deployment

Persistent storage is deployed first because Moodle requires application data to survive container replacement.
```bash
kubectl apply -f kubernetes/storage/moodle-storage.yaml
```

Verify storage resources:
```bash
kubectl get pv
kubectl get pvc
```

---

# Database Deployment (MySQL)

Deploy the database layer:
```bash
kubectl apply -f kubernetes/mysql/
```

Restart if required:
```bash
kubectl rollout restart deployment mysql
```

Monitor startup:
```bash
kubectl get pods -w
```

---

# Build and Deploy PHP/Moodle Application

The PHP image is customized because Moodle requires additional PHP extensions and runtime configuration.

Build the custom image:
```bash
docker build -t extn-php:8.2 .
```

Load the image into the KinD cluster:
```bash
kind load docker-image extn-php:8.2 --name lab
```

Deploy PHP:
```bash
kubectl apply -f kubernetes/php/
```

Restart PHP after image updates:
```bash
kubectl rollout restart deployment php
```

Monitor startup:
```bash
kubectl get pods -w
```

Check Moodle initialization:
```bash
kubectl logs deploy/php -c init-moodle
```

---

# Nginx Web Server Deployment

Deploy the frontend web server:
```bash
kubectl apply -f kubernetes/nginx/
```

Restart after configuration changes:
```bash
kubectl rollout restart deployment nginx
```

Monitor startup:
```bash
kubectl get pods -w
```

Verify Nginx configuration:
```bash
kubectl exec deploy/nginx -- nginx -t
```

Expected:
```text
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Inspect active routing configuration:
```bash
kubectl exec deploy/nginx -- nginx -T | grep "server_name"
```

Expected:
```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successfulfastcgi_param  SERVER_NAME        $server_name;
```

View the logs:
```bash
kubectl logs <nginx-pod-name>
```


---

## Verify DB exists

Connect to DB:
```bash
kubectl exec -it deploy/mysql -- mysql -u root -p
```

SQL Query:
```sql
SHOW DATABASES;
```

Expected output:
```text
+--------------------+
| Database           |
+--------------------+
| information_schema |
| moodle             |
| mysql              |
| performance_schema |
| sys                |
+--------------------+	
5 rows in set (0.02 sec)
```

SQL Query:
```sql
USE moodle;
SELECT 1;
```

---

## Verify PHP Runtime Configuration

Confirm Moodle PHP settings:
```bash
kubectl exec deploy/php -- php -i | grep -E "memory_limit|max_execution_time|max_input_vars"
```
Expected:
```text
memory_limit=512M
max_execution_time=300
max_input_vars=5000
```


---

# Ingress Routing

Deploy the ingress controller:
```bash
kubectl apply -f ingress-nginx.yaml
```

Wait for the ingress controller (Ready=1/1):
```bash
kubectl get pods -n ingress-nginx -w
```

Apply Moodle ingress rules:
```bash
kubectl apply -f kubernetes/overlays/local-kind/ingress.yaml
```

Verify ingress resources:
```bash
kubectl get ingress
kubectl describe ingress
```

If the admission webhook becomes stuck due to stale local cluster state:
```bash
kubectl delete validatingwebhookconfiguration ingress-nginx-admission
```

Find Ingress pod
```bash (
kubectl get pods -n ingress-nginx
```

Validation
The ingress controller was verified running on the worker node:
```bash
kubectl get pods -n ingress-nginx -o wide
```

Expected:
```text
NAME                                      NODE
ingress-nginx-controller-xxxxx            lab-worker
```

View the logs:
```bash
kubectl logs -n ingress-nginx <ingress-nginx-controller-pod>
```


---

# Storage Verification

Verify persistent volume claims:
```bash
kubectl get pvc
```

Expected after application deployment:
```text
STATUS = Bound
```

This confirms that application workloads have successfully claimed the persistent storage required by Moodle.

---

# Localhost Access Verification

After the Ingress controller and Moodle ingress rules are deployed, verify that the application is reachable:
```text
http://localhost
```

Expected result:

- Moodle installation page loads in the browser.
- Nginx is successfully routing incoming traffic.
- PHP-FPM and MySQL backend connectivity is available.

---

# Moodle Web Installation

Complete the Moodle installation wizard using the following sequence:

**Choose Language**
- Select the installation language.

**Confirm Paths**
- Verify the web address and Moodle data directory.

**Choose Database Driver**
- Select the database type:
  - MySQL / MariaDB

**Database Settings**
- Enter the database configuration:

| Setting | Value |
| :--- | :--- |
| **Web Address** | `http://localhost` |
| **Moodle Directory** | `/var/www/html` |
| **Moodle Data Directory** | `/var/www/moodledata` |
| **Database Type** | `MySQL` |
| **Database Host** | `mysql` |
| **Database Port** | `3306` |
| **Database Name** | `moodle` |
| **Database User** | `<MYSQL_USER from .env>` |
| **Database Password** | `<MYSQL_PASSWORD from .env>` |
| **Table Prefix** | `mdl_` |

**Copyright Notice**
- Accept the Moodle GPL license agreement.

**Server Checks**
- Review PHP extensions and environment requirements.
- Continue once all required checks pass.

**Installation**
- Allow Moodle to create the database tables and complete application initialization.

**Setup Administrator Account**
- Complete administrator configuration.

**Front Page Settings** 
- Configure your site’s name, short name, and provide a brief front-page description or welcome message.

*Note: The database table prefix (`mdl_`) must remain identical across all deployment phases and upgrades. Changing this value causes Moodle to drop its mapping to existing tables, generating an empty schema and resulting in total application data loss.*


---

# Application Recovery and Data Persistence

This test verifies that Kubernetes can recreate the PHP workload while maintaining Moodle application data stored on persistent storage.

### Create Moodle Test Data

Before deleting the PHP pod, create test data within Moodle:

1. Log into Moodle as the administrator.
2. Complete and save the administrator profile.
3. Upload an administrator profile image.
4. Create a test course:
```text
Infrastructure Test Course
```
5. Upload a course image.
6. Confirm both images render correctly before pod recreation.

### Verify Current PHP Image

Before deleting the pod, verify the current PHP deployment image:
```bash
kubectl get deployment php -o jsonpath="{.spec.template.spec.containers[0].image}"
```

Expected:
```text
extn-php:8.2
```

### Recreate the PHP Workload

Delete the PHP pod:
```bash
kubectl delete pod -l app=php
```

Verify Kubernetes creates a replacement pod:
```bash
kubectl get pods -w
```

Example result:
```text
mysql-xxxxx   1/1   Running   0   4d4h
nginx-xxxxx   1/1   Running   0   4d4h
php-yyyyy     1/1   Running   0   84s
```

The new PHP pod name and recent age confirm Kubernetes recreated the workload.

### Verify Application Availability

Verify Moodle application files are still available:
```bash
kubectl exec deploy/php -- ls /var/www/html
```

Expected:
```text
Existing Moodle files are still present
```

Confirm the application is still accessible:
```text
http://localhost
```

### Validate Moodle Persistence

After the replacement pod becomes available, log back into the web UI to verify data consistency:

1. Log into Moodle as administrator.
2. Verify the custom administrator profile image persists.
3. Access the `Infrastructure Test Course` and confirm the course image renders correctly.

This successfully validates:
* **Workload Resilience:** Kubernetes successfully rescheduled and stabilized the replacement PHP pod.
* **Storage Persistence:** Persistent Volume Claims safely retained all Moodle core files and user-uploaded media.
* **State Recovery:** The application recovered seamlessly without requiring manual configuration or setup runs.


## Destroy Environment

Use when rebuilding the complete environment:
```bash
kind delete cluster --name lab
```

This removes the Kubernetes cluster, workloads, services, and pods.

---

## Reset Application Data

Use when keeping the cluster but removing persistent Moodle data:
```bash
kubectl delete pvc --all
```
If you want to restart workloads:
```bash
kubectl delete pods --all
```
---

## Remove Unused Docker Resources

Optional cleanup:
```bash
docker system prune -a --volumes -f
```
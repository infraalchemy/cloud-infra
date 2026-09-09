# Phase 3 Deployment Runbook: Cloud Kubernetes Deployment with Google Kubernetes Engine (GKE)

This guide documents the complete process used to build, deploy, validate, and rebuild a cloud containerized Moodle environment. The entire architecture runs within a managed multi-node Kubernetes cluster provisioned via Google Kubernetes Engine (GKE).

---

# Prerequisites

This project deploys a cloud Kubernetes environment using Google Cloud Platform (GCP).

Required software:

* Google Cloud CLI
* kubectl
* gke-gcloud-auth-plugin
* Docker
* Kustomize (included with kubectl)
* Git

Verify installations:

```bash
gcloud --version
kubectl version --client
gke-gcloud-auth-plugin --version
docker --version
git --version
```

---

# Google Cloud Environment Setup

Authenticate to Google Cloud:
```bash
gcloud auth login
```

Verify the authenticated account:
```bash
gcloud auth list
```

Set the GCP project used for the deployment:
```bash
gcloud config set project <PROJECT-ID>
```

Verify the active project:
```bash
gcloud config get-value project
```
*Expected:*
```text
<PROJECT-ID>
```

---

# Artifact Registry and Custom PHP Image

The custom PHP image is built from the project Dockerfile and stored in Google Artifact Registry so it can be pulled by the GKE cluster during deployment.

*Note: The Artifact Registry repository is created only during the initial GCP deployment. When rebuilding the GKE environment, reuse the existing repository. Rebuild and push the custom PHP image only when the Dockerfile or image configuration has changed.*

## Enable Artifact Registry

Enable the Google Artifact Registry service:
```bash
gcloud services enable artifactregistry.googleapis.com
```

---

## Create Artifact Registry Repository

Create the Docker repository in the `northamerica-northeast2` region:
```bash
gcloud artifacts repositories create moodle-repo \
  --repository-format=docker \
  --location=northamerica-northeast2 \
  --description="Docker repository for Moodle custom PHP"
```

Verify that the repository was created:
```bash
gcloud artifacts repositories list
```

---

## Configure Docker Authentication

Configure Docker authentication for the Artifact Registry region:
```bash
gcloud auth configure-docker northamerica-northeast2-docker.pkg.dev
```

---

## Build Custom PHP Image

Build the custom PHP image from the project Dockerfile and tag it for Artifact Registry:
```bash
docker build -t northamerica-northeast2-docker.pkg.dev/<PROJECT-ID>/moodle-repo/custom-php:8.2 .
```

---

## Push Custom PHP Image

Push the custom PHP image to Artifact Registry:
```bash
docker push northamerica-northeast2-docker.pkg.dev/<PROJECT-ID>/moodle-repo/custom-php:8.2
```

---

## Verify Custom PHP Image

Verify that the custom PHP image is available in Artifact Registry:
```bash
gcloud artifacts docker images list \
  northamerica-northeast2-docker.pkg.dev/<PROJECT-ID>/moodle-repo
```
*Expected:*
```text
IMAGE: northamerica-northeast2-docker.pkg.dev/<PROJECT-ID>/moodle-repo/custom-php
DIGEST: sha256:<digest>
CREATE_TIME: <timestamp>
UPDATE_TIME: <timestamp>
SIZE: <size>
```

---

# Deployment Workflow

The deployment follows this sequence:

1. Create GKE cluster
2. Reserve global static IP address
3. Enable Filestore CSI driver
4. Deploy persistent storage
5. Deploy MySQL database
6. Deploy custom PHP/Moodle application image
7. Deploy Nginx web server
8. Configure domain DNS
9. Configure Ingress routing and SSL certificate
10. Complete Moodle installation and configuration
11. Verify application access


---

# GKE Cluster Setup

Check for an existing GKE cluster:
```bash
gcloud container clusters list
```

If `moodle-gke-cluster` exists and the environment is being rebuilt, delete the existing cluster:
```bash
gcloud container clusters delete moodle-gke-cluster \
  --zone northamerica-northeast2-a \
  --quiet
```

Verify the cluster has been removed:
```bash
gcloud container clusters list
```

---

## Create Cluster

Create the cloud GKE cluster:
```bash
gcloud container clusters create moodle-gke-cluster \
  --zone northamerica-northeast2-a \
  --num-nodes 2 \
  --machine-type e2-medium
```

Verify cluster nodes:
```bash
kubectl get nodes
```
*Expected:*
```text
NAME                                                STATUS   ROLES    AGE     VERSION
gke-moodle-gke-cluster-default-pool-da0fe6b4-0wll   Ready    <none>   2m59s   v1.35.6-gke.1641000
gke-moodle-gke-cluster-default-pool-da0fe6b4-5lbk   Ready    <none>   3m      v1.35.6-gke.1641000
```

---

## Promote Global Static IP

Reserve a static external IP address for the cloud load balancer:
```bash
gcloud compute addresses create moodle-static-ip --global
```
*Expected:*
```text
Created [https://www.googleapis.com/compute/v1/projects/<Project ID>/global/addresses/moodle-static-ip].
```

Verify the reserved static IP:
```bash
gcloud compute addresses describe moodle-static-ip --global --format="value(address)"
```
*Expected:*
```text
<Static IP>
```

---

## Configure Cluster Context

Connect kubectl to the GKE cluster by generating the local kubeconfig entries:
```bash
gcloud container clusters get-credentials moodle-gke-cluster \
  --zone northamerica-northeast2-a
```
*Expected:*
```text
kubeconfig entry generated for moodle-gke-cluster.
```

---

# Workload Deployment Phase

Deploy the Kubernetes workloads in the following order: Filestore CSI driver, persistent storage, MySQL, PHP and Nginx. This sequence ensures required storage and backend services are available before dependent workloads are deployed.


## Enable Filestore CSI Driver (RWX Storage)

Enable the Google Cloud Filestore CSI driver addon on the cluster to provide ReadWriteMany (RWX) storage capabilities:
```bash
gcloud container clusters update moodle-gke-cluster \
  --location northamerica-northeast2-a \
  --update-addons=GcpFilestoreCsiDriver=ENABLED
```

Verify that the RWX storage class is available:
```bash
kubectl get storageclass
```
*Expected:*
```text
NAME           PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard-rwx   filestore.csi.storage.gke.io   Delete          WaitForFirstConsumer   true                   2m
```

Verify that the Filestore CSI driver pods are running successfully:
```bash
kubectl get pods -n kube-system | grep filestore
```
*Expected:*

```text
filestore-lock-release-controller-649558dd5d-mcq4c   2/2   Running   0   2m22s
filestore-node-tr7sb                                 4/4   Running   0   2m22s
filestore-node-xxkq6                                 4/4   Running   0   2m22s
```

---

## Deploy Persistent Storage Layer

Allow Kustomize to load referenced files outside the immediate kustomization directory:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/storage/
```

Deploy the persistent storage layer:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/storage/ | kubectl apply -f -
```

Verify the PersistentVolumeClaims:

```bash
kubectl get pvc
```

*Expected:*

```text
NAME             STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
moodle-pvc       Pending                                                                        standard-rwx   22s
moodledata-pvc   Bound     pvc-168e041c-22d5-4dbf-ba70-0947e5c9c6b0   5Gi        RWO            standard       22s
```

*Note: `moodle-pvc` remains `Pending` because the `standard-rwx` storage class uses `WaitForFirstConsumer`. The volume is provisioned when a pod requiring the claim is scheduled.*

---

## Deploy MySQL Database

Allow Kustomize to load referenced files outside the immediate kustomization directory:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/mysql/
```

Deploy the MySQL database:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/mysql/ | kubectl apply -f -
```

Verify the MySQL pod is running:

```bash
kubectl get pods -w
```

Connect to the MySQL database:

```bash
kubectl exec -it deploy/mysql -- mysql -u root -p
```

Verify the Moodle database exists:

```sql
SHOW DATABASES;
```

*Expected:*

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

Select the Moodle database and verify the database connection:

```sql
USE moodle;
SELECT 1;
```

---

## Deploy PHP Application

Allow Kustomize to load referenced files outside the immediate kustomization directory:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/php/
```

Deploy the PHP application:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/php/ | kubectl apply -f -
```

Verify the PHP pod is running:

```bash
kubectl get pods -w
```

Verify the deployed PHP image:

```bash
kubectl get deployment php \
  -o jsonpath="{.spec.template.spec.containers[0].image}"
```

*Expected:*

```text
northamerica-northeast2-docker.pkg.dev/civic-champion-439320-a5/moodle-repo/custom-php:8.2
```

Verify the PHP version:

```bash
kubectl exec -it deploy/php -- sh
# Inside container:
php -v
```

Confirm the Moodle PHP settings:

```bash
kubectl exec deploy/php -- cat /usr/local/etc/php/conf.d/moodle.ini
```

*Expected:*

```text
memory_limit=512M
max_execution_time=300
max_input_vars=5000
```

Verify the Moodle application and data directory permissions:
```powershell
kubectl exec deploy/php -- sh -c 'ls -ld /var/www/html /moodledata'
```

Verify the required Moodle PHP extensions are loaded:
```bash
kubectl exec deploy/php -- php -m | grep -E "mysqli|pdo_mysql|gd|intl|zip|opcache"
```

Verify the Moodle application files are present:
```powershell
kubectl exec deploy/php -- ls /var/www/html
```

---

## Deploy Nginx Web Server

Allow Kustomize to load referenced files outside the immediate kustomization directory:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/nginx/
```

Deploy the Nginx web server:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/nginx/ | kubectl apply -f -
```

Verify the Nginx pod is running:
```bash
kubectl get pods -w
```

Verify the live Nginx Service configuration:
```bash
kubectl get service nginx -o yaml
```
*Expected:*
The Nginx Service includes the BackendConfig and Network Endpoint Group (NEG) annotations:
```yaml
metadata:
  annotations:
    cloud.google.com/backend-config: '{"default":"nginx-backend-config"}'
    cloud.google.com/neg: '{"ingress":true}'
```

Verify the Nginx BackendConfig configuration:
```bash
kubectl get backendconfig nginx-backend-config -o yaml
```
*Expected:*
The BackendConfig includes the `/healthz` health check path:
```yaml
spec:
  healthCheck:
    requestPath: /healthz
```

## Verify Workload Deployment
```bash
kubectl get pods
kubectl get svc
kubectl get endpoints nginx
kubectl get pvc
```

---

# Configure Domain DNS

Configure the domain DNS record to point to the reserved static IP address.

Verify the reserved static IP:
```bash
gcloud compute addresses describe moodle-static-ip --global --format="value(address)"
```
*Expected:*
```text
<Static IP>
```

Open the domain management console and navigate to the DNS records for the domain.

Add an A record with the following configuration:

- **Type**: Select `A - Address Record`
- **Host**: Leave empty
- **Answer**: Enter `<Static IP>`
- **TTL**: Leave at `600` or the existing default value

Save the DNS record.
*Expected:*
```text
A  <Domain Name>  <Static IP>
```

---

# Deploy Ingress and SSL Certificate

Expose the application to the internet through the GKE Ingress and configure SSL.

Allow Kustomize to load referenced files outside the immediate kustomization directory:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/overlays/
```

Deploy the Ingress and SSL certificate configuration:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/overlays/ | kubectl apply -f -
```

Verify the Ingress health:
```bash
kubectl describe ingress moodle-ingress
```
*Expected:*
```text
Annotations:  ingress.kubernetes.io/backends:
                {"k8s1-1c544d72-default-nginx-80-d46c5d31":"HEALTHY","k8s1-1c544d72-kube-system-default-http-backend-80-591b856c":"HEALTHY"}
				kubernetes.io/ingress.class: gce
				kubernetes.io/ingress.global-static-ip-name: moodle-static-ip
				networking.gke.io/managed-certificates: moodle-ssl-cert
```
*Note* GCE Ingress is being used, it's tied to Terraform-created moodle-static-ip, the managed certificate is attached, and Google considers the Nginx backend healthy.


Wait for the Ingress to receive an external IP address:
```bash
kubectl get ingress moodle-ingress -w
```
*Expected:*

```text
NAME             CLASS    HOSTS   ADDRESS        PORTS   AGE
moodle-ingress   <none>   *                      80      113s
moodle-ingress   <none>   *       34.49.127.103  80      3m38s
moodle-ingress   <none>   *       34.49.127.103  80      3m40s
```

Verify routing to the static IP using the domain Host header:
```bash
curl -I -H "Host: <Domain Name>" http://<Static IP>
```
*Expected:*
```text
HTTP/1.1 200 OK
```

A `301` or `302` redirect is also expected if Nginx or Moodle redirects HTTP traffic to HTTPS.

Verify the domain directly:
```bash
curl -I http://<Domain Name>
```
*Expected:*

```text
HTTP/1.1 200 OK
```

---

# Run the Automated Moodle CLI Installer

Run the Moodle CLI installer to create the database tables and complete the initial Moodle installation. Use the internal MySQL Cluster IP for `--dbhost` and `/moodledata` for `--dataroot`.

Refresh the GKE cluster credentials:
```cloudshell
gcloud container clusters get-credentials moodle-gke-cluster \
  --zone northamerica-northeast2-a
```
*Expected:*
```text
kubeconfig entry generated for moodle-gke-cluster.
```

## Get the MySQL Cluster IP

Retrieve the internal MySQL Cluster IP:
```bash
kubectl get svc mysql
```

## Run the Moodle CLI Installer

Run the Moodle CLI installer from the PHP pod using the MySQL Cluster IP and static IP:
```cloudshell
kubectl exec -it (kubectl get pods -l app=php -o jsonpath='{.items[0].metadata.name}') -- php /var/www/html/admin/cli/install.php \
--lang=en \
--dbtype=mysqli \
--dbhost="<DB IP>" \
--dbport=3306 \
--dbname=moodle \
--dbuser=moodleuser \
--dbpass=<moodle password> \
--dataroot="/moodledata" \
--wwwroot="http://<Static IP>" \
--fullname="<Moodle Site Name>" \
--shortname="<MSN>" \
--adminuser=admin \
--adminpass=<Admin Password> \
--adminemail=<xxxx.gmail.com> \
--agree-license \
--non-interactive
```

---

# Configure Moodle for GKE Ingress

Overwrite the generated `config.php` with the required database, domain, and proxy settings.

## Configure Moodle Settings

Set `wwwroot` to the HTTPS domain name and configure Moodle to operate behind the GKE Ingress.
- **`wwwroot`**: Use the HTTPS domain name to ensure Moodle generates the correct application URLs.
- **`adminpass`**: Ensure the administrator password meets the Moodle password policy.

```powershell
kubectl exec -it deploy/php -- sh -c "cat << 'EOF' > /var/www/html/config.php
<?php  // Moodle configuration file
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mysqli';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '<DB IP>';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'moodleuser';
\$CFG->dbpass    = '<moodle password>';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => 3306,
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = 'https://<Domain Name>';
\$CFG->dataroot  = '/moodledata';
\$CFG->admin     = 'admin';
\$CFG->directorypermissions = 02777;

\$CFG->getremoteaddrconf = 2;
\$CFG->sslproxy = 1;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF"
```

## Apply File Ownership and Permissions

Apply the required ownership and permissions to `config.php` and the Moodle data directory:
```powershell
kubectl exec -it deploy/php -- chown 33:33 /var/www/html/config.php
kubectl exec -it deploy/php -- chmod 644 /var/www/html/config.php
kubectl exec -it deploy/php -- chmod 777 /moodledata
kubectl exec -it deploy/php -- chown -R 33:33 /moodledata
```

Verify the Moodle application and data directory permissions:
```powershell
kubectl exec deploy/php -- sh -c 'ls -ld /var/www/html /moodledata'
```
*Expected:*
```text
drwxrwsrwx 10 www-data www-data 4096 Aug 27 18:54 /moodledata
drwxr-xr-x 65 www-data www-data 4096 Aug 27 18:53 /var/www/html
```

---

# Verify Application Access

Access the Moodle application through the configured domain:
```text
https://<Domain Name>
```

---

# Maintenance: Refresh Cluster Credentials

Refresh the GKE cluster credentials if the local kubectl credentials expire or access to the GKE control plane is lost:
```bash
gcloud container clusters get-credentials moodle-gke-cluster \
  --zone northamerica-northeast2-a
```
*Expected:*

```text
kubeconfig entry generated for moodle-gke-cluster.
```

---

# Destroy GKE Environment

Remove the Kubernetes workloads and GCP resources when the environment is no longer required or before rebuilding from a clean state.


## Delete Kubernetes Workloads

Delete the Ingress and SSL resources:
```bash
kubectl delete -k kubernetes/gcp-gke/overlays/
```

Wait for the resources to finish deleting before continuing.

Delete the Nginx resources:
```bash
kubectl delete -k kubernetes/gcp-gke/nginx/
```

Wait for the resources to finish deleting before continuing.

Delete the PHP resources:
```bash
kubectl delete -k kubernetes/gcp-gke/php/
```

Wait for the resources to finish deleting before continuing.

Delete the MySQL resources:
```bash
kubectl delete -k kubernetes/gcp-gke/mysql/
```

Wait for the resources to finish deleting before continuing.

Delete the persistent storage resources:
```bash
kubectl delete -k kubernetes/gcp-gke/storage/
```

---

## Delete GKE Cluster

Delete the GKE cluster and its worker nodes:
```bash
gcloud container clusters delete moodle-gke-cluster \
  --zone northamerica-northeast2-a
```

---

## Release Global Static IP

Delete the reserved global static IP address:
```bash
gcloud compute addresses delete moodle-static-ip --global
```

---

## Verify Persistent Disks and Artifact Registry Cleanup

After deleting the environment, verify that no persistent resources remain.

### Verify Persistent Disks

In the Google Cloud Console:

1. Go to **Compute Engine → Disks**
2. Check for any disks associated with the deleted environment
3. Delete any disks that are no longer required

### Verify Artifact Registry Repository

Check whether the Artifact Registry repository still exists:

```bash
gcloud artifacts repositories list \
  --project civic-champion-439320-a5 \
  --location northamerica-northeast2
```

If the repository exists, check whether it contains any Docker images:

```bash
gcloud artifacts docker images list \
  northamerica-northeast2-docker.pkg.dev/civic-champion-439320-a5/moodle-repo
```

Delete the repository and all images stored within it:

```bash
gcloud artifacts repositories delete moodle-repo \
  --location=northamerica-northeast2 \
  --project civic-champion-439320-a5
```
*Expected:*

```text
Deleted repository [moodle-repo].
```

Verify that the repository has been removed:

```bash
gcloud artifacts repositories list \
  --project civic-champion-439320-a5 \
  --location northamerica-northeast2
```
*Expected:*

```text
Listed 0 items.
```




# Phase 3 Deployment Runbook: Cloud Kubernetes Deployment with Google Kubernetes Engine (GKE)

This guide documents the complete process used to build, deploy, validate, and rebuild a cloud containerized Moodle environment. The entire architecture runs within a managed multi-node Kubernetes cluster provisioned via Google Kubernetes Engine (GKE).

---

# Prerequisites

This project deploys a cloud Kubernetes environment using Google Cloud Platform (GCP).

Required software:
- Google Cloud CLI
- kubectl
- gke-gcloud-auth-plugin
- Docker
- Kustomize (included with kubectl)

Verify installations:
```bash
gcloud --version
kubectl version --client
gke-gcloud-auth-plugin --version
docker --version
```

---

# GKE Cluster Setup

Use when recreating the environment from a clean state.
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
<static IP>
```

---

## Verify External IP Assets

Verify and find the resource name of the allocated static IP address:

```bash
gcloud compute addresses list
```
*Expected:*
```text
NAME: moodle-static-ip
ADDRESS/RANGE: 136.69.90.210
TYPE: EXTERNAL
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

Deploy workloads in strict sequence: Storage assets must be established first to provision the required PersistentVolumeClaims (PVCs), followed by the MySQL database instance, and finally the PHP application layer paired with the Nginx web server.

---

## 01 Enable Filestore CSI Driver (RWX Storage)

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
filestore-lock-release-controller-649558dd5d-mcq4c             2/2     Running   0          2m22s
filestore-node-tr7sb                                           4/4     Running   0          2m22s
filestore-node-xxkq6                                           4/4     Running   0          2m22s
```

---

## 02 Deploy Persistent Storage Layer

Build and apply the Kustomize manifests for the storage infrastructure. The `--load-restrictor LoadRestrictionsNone` flag bypasses default host directory execution rules:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/storage/ | kubectl apply -f -
```

Verify the state of the PersistentVolumeClaims:
```bash
kubectl get pvc
```
*Expected:*
```text
NAME             STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
moodle-pvc       Pending                                                                        standard-rwx   22s
moodledata-pvc   Bound     pvc-168e041c-22d5-4dbf-ba70-0947e5c9c6b0   5Gi        RWO            standard       22s
```
*(Note: `moodle-pvc` remains Pending under `WaitForFirstConsumer` until the pods requiring it are scheduled).*

---
# Phase 3 Deployment Runbook: Cloud Kubernetes Deployment with Google Kubernetes Engine (GKE)

This guide documents the complete process used to build, deploy, validate, and rebuild a cloud containerized Moodle environment. The entire architecture runs within a managed multi-node Kubernetes cluster provisioned via Google Kubernetes Engine (GKE).

---

# Prerequisites

This project deploys a cloud Kubernetes environment using Google Cloud Platform (GCP).

Required software:
- Google Cloud CLI
- kubectl
- gke-gcloud-auth-plugin
- Docker
- Kustomize (included with kubectl)

Verify installations:
```bash
gcloud --version
kubectl version --client
gke-gcloud-auth-plugin --version
docker --version
```

---

# GKE Cluster Setup

Use when recreating the environment from a clean state.
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
<static IP>
```

---

## Verify External IP Assets

Verify and find the resource name of the allocated static IP address:

```bash
gcloud compute addresses list
```
*Expected:*
```text
NAME: moodle-static-ip
ADDRESS/RANGE: 136.69.90.210
TYPE: EXTERNAL
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

Deploy workloads in strict sequence: Storage assets must be established first to provision the required PersistentVolumeClaims (PVCs), followed by the MySQL database instance, and finally the PHP application layer paired with the Nginx web server.

---

## 01 Enable Filestore CSI Driver (RWX Storage)

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
filestore-lock-release-controller-649558dd5d-mcq4c             2/2     Running   0          2m22s
filestore-node-tr7sb                                           4/4     Running   0          2m22s
filestore-node-xxkq6                                           4/4     Running   0          2m22s
```

---

## 02 Deploy Persistent Storage Layer

Build and apply the Kustomize manifests for the storage infrastructure. The `--load-restrictor LoadRestrictionsNone` flag bypasses default host directory execution rules:

```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/storage/ | kubectl apply -f -
```

Verify the state of the PersistentVolumeClaims:
```bash
kubectl get pvc
```
*Expected:*
```text
NAME             STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
moodle-pvc       Pending                                                                        standard-rwx   22s
moodledata-pvc   Bound     pvc-168e041c-22d5-4dbf-ba70-0947e5c9c6b0   5Gi        RWO            standard       22s
```
*(Note: `moodle-pvc` remains Pending under `WaitForFirstConsumer` until the pods requiring it are scheduled).*


---

## 03 MySQL

Relaxes Kustomize's file-loading security restriction:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/mysql/
```

Deploy:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/mysql/ | kubectl apply -f -
```

Verify pod if running:
```bash
kubectl get pods -w
```

Connect to DB:
```bash
kubectl exec -it deploy/mysql -- mysql -u root -p
```

SQL Query:
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

SQL Query:
```sql
USE moodle;
SELECT 1;
```

---

## 04 PHP

Relaxes Kustomize's file-loading security restriction:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/php/
```

Deploy:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/php/ | kubectl apply -f -
```

Verify pod if running:
```bash
kubectl get pods -w
```

Verify the PHP image:
```bash
kubectl get deployment php \
  -o jsonpath="{.spec.template.spec.containers[0].image}"
```
*Expected:*
```text
northamerica-northeast2-docker.pkg.dev/civic-champion-439320-a5/moodle-repo/custom-php:8.2
```

Deep test (PHP info page):
```bash
kubectl exec -it deploy/php -- sh
# Inside container:
php -v
```

Confirm Moodle PHP settings (use Powershell):
```bash
kubectl exec deploy/php -- cat /usr/local/etc/php/conf.d/moodle.ini
```
*Expected:*
```text
memory_limit=512M
max_execution_time=300
max_input_vars=5000
```

Verify Moodle Data Permissions:
```bash
kubectl exec deploy/php -- sh -c 'ls -ld /var/www/html /moodledata'
```

Verify Essential Moodle Extensions are Loaded:
```bash
kubectl exec deploy/php -- php -m | grep -E "mysqli|pdo_mysql|gd|intl|zip|opcache"
```

Verify /var/www/html populated (use Powershell):
```bash
kubectl exec deploy/php -- ls /var/www/html
```

---

## 05 Nginx

Relaxes Kustomize's file-loading security restriction:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone kubernetes/gcp-gke/nginx/
```

Deploy:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/nginx/ | kubectl apply -f -
```

Verify pod if running:
```bash
kubectl get pods -w
```

The complete live Kubernetes configuration:
```bash
kubectl get service nginx -o yaml
```
*Expected:*
Live service has:
```yaml
metadata:
  annotations:
    cloud.google.com/backend-config: '{"default":"nginx-backend-config"}'
    cloud.google.com/neg: '{"ingress":true}'
```

```bash
kubectl get backendconfig nginx-backend-config -o yaml
```
Expected:
The BackendConfig is present and GKE has exactly the health check we intended:
```yaml
spec:
  healthCheck:
    requestPath: /healthz
```


Verify before deploying ingress:
```bash
kubectl get pods
kubectl get svc
kubectl get endpoints nginx
kubectl get pvc
```

---

## Step 6. Point Your Domain DNS

Update your domain mapping.

Go domain management -> domain -> details -> DNS Records click check box
- **Type**: Click the dropdown menu and select `A - Address Record`.
- **Host**: Leave this box completely empty.
- **Answer**: Type `<static IP>`
- **TTL**: Leave it at `600` (or whatever number is already there).
- Click the **Add** button.

Expected:
```text
A  <Domain Name>  <Static IP>
```

---

## Step 7. Deploy the Ingress & SSL Certificate

Expose the application to the internet securely.

Relaxes Kustomize's file-loading security restriction:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/overlays/
```

Deploy:
```bash
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/overlays/ | kubectl apply -f -
```

Verify ingress health:
```bash
kubectl describe ingress moodle-ingress
```
*Expected:*
```text
Annotations:  ingress.kubernetes.io/backends:
                {"k8s1-1c544d72-default-nginx-80-d46c5d31":"HEALTHY","k8s1-1c544d72-kube-system-default-http-backend-80-591b856c":"HEALTHY"}
Events:
  Type    Reason  Age                  From                     Message
  ----    ------  ----                 ----                     -------
  Normal  Sync    115s (x2 over 115s)  loadbalancer-controller  Scheduled for sync
```

#### Wait until ADDRESS gets an external IP:
```bash
kubectl get ingress moodle-ingress -w
```
*Expected:*
```text
NAME             CLASS    HOSTS   ADDRESS   PORTS   AGE
moodle-ingress   <none>   *                 80      113s
moodle-ingress   <none>   *       34.49.127.103   80      3m38s
moodle-ingress   <none>   *       34.49.127.103   80      3m40s
```

Verify Spoof the Host Header (Instant Verification):
```bash
curl -I -H "Host: <Domain Name>" http://<Static IP>
```
*Expected:*
```text
Return an HTTP/1.1 200 OK or a 301/302 Redirect if Nginx or Moodle forces HTTPS
```

Verify domain directly:
```bash
curl -I http://<Domain Name>
```
*Expected:*
```text
HTTP/1.1 200 OK
```

---

## Step 8. Run the Automated Moodle CLI Installer

Build the database tables natively. Execute the install.php CLI command inside your running PHP pod using the direct internal Cluster-IP for --dbhost and /moodledata for --dataroot.

```bash
# Connect kubectl to GKE kubeconfig entry generated for moodle-gke-cluster. (Cloud Shell, bash or PowerShell)
gcloud container clusters get-credentials moodle-gke-cluster \
  --zone northamerica-northeast2-a
```
*Expected:*
```text
kubeconfig entry generated for moodle-gke-cluster.
```

1. Get your internal MySQL Cluster IP:
```bash
kubectl get svc mysql
```

2. Run the Installer (Note: use your new static IP from step 2 for --wwwroot!):
```bash
kubectl exec -it (kubectl get pods -l app=php -o jsonpath='{.items[0].metadata.name}') -- php /var/www/html/admin/cli/install.php `
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

3. Apply File Permissions & Proxy Settings (Use Powershell):
Lock down the app parameters.

Run chmod 644 /var/www/html/config.php. Inject `$CFG->sslproxy = 1;` and `$CFG->getremoteaddrconf = 2;` above the require_once block inside config.php to instantly stop the redirect loops.

---

## Step 9. Overwrite the config.php cleanly to include proxy fixes ABOVE require_once

### 1. Critical Installation Tips
- **`--wwwroot`**: Notice this is set to use `https://`. Because Moodle is highly strict about its security URL, using the domain name here ensures links don't break later.
- **`--adminpass`**: Ensure your password meets Moodle's default password policy (usually at least 8 characters, 1 digit, 1 lowercase, 1 uppercase, and 1 non-alphanumeric character).

```bash
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

\$CFG->wwwroot   = '<Domain Name>';
\$CFG->dataroot  = '/moodledata';
\$CFG->admin     = 'admin';
\$CFG->directorypermissions = 02777;

\$CFG->getremoteaddrconf = 2;  # Moodle identifies the real IP address of your visitors.
\$CFG->sslproxy = 1;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF"
```

### 2. Secure ownership and directory permissions immediately after creation

```bash
kubectl exec -it deploy/php -- chown 33:33 /var/www/html/config.php
kubectl exec -it deploy/php -- chmod 644 /var/www/html/config.php
kubectl exec -it deploy/php -- chmod 777 /moodledata
kubectl exec -it deploy/php -- chown -R 33:33 /moodledata
```

Verify Moodle Data Permissions (powershell):
```bash
kubectl exec deploy/php -- sh -c 'ls -ld /var/www/html /moodledata'
```
*Expected:*
```text
drwxrwsrwx 10 www-data www-data 4096 Aug 27 18:54 /moodledata
drwxr-xr-x 65 www-data www-data 4096 Aug 27 18:53 /var/www/html
```

---

## Step 10. Verify via Web Browser

Access your application directly via the mapped domain using an external web browser:
```text
http://<Domain Name>
```

---

## Step 11. Maintenance: Refresh Cluster Credentials

Use this step if your cluster connection tokens expire or you lose contact with the GKE control plane during the configuration process.

```bash
gcloud container clusters get-credentials moodle-gke-cluster --zone=northamerica-northeast2-a
```
*Expected:*
```text
kubeconfig entry generated for moodle-gke-cluster.
```






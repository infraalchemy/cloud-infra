# Kubernetes Deployment Post-Mortem

Deploying a multi-tier stateful application like Moodle into a local Kubernetes cluster introduced architectural challenges involving networking, storage, initialization, and application configuration. This document captures the troubleshooting process and lessons learned while migrating the Moodle container stack from Docker Compose to a local Kubernetes environment using KinD.

## 1. The Ghost Port Blockade & Local Network Conflict (Windows Layer & Cluster Configuration)

* **The Problem:** I encountered a flat refusal to connect on `localhost`. Running a process trace revealed stale background instances of `com.docker.backend.exe` and `wslrelay.exe` holding host ports 80 and 443. Additionally, my initial KinD cluster configuration exposed secure traffic through host port `443`, which conflicted with the local cluster networking configuration.

* **The Fix:** I cleared stale Docker Desktop and WSL2 networking state using `Stop-Process` and `wsl --shutdown`. I then recreated the KinD cluster with updated port mappings, moving secure web traffic to host port `8443` while keeping the Kubernetes cluster networking isolated.

```yaml
hostPort: 80          # HTTP traffic
hostPort: 8443        # HTTPS traffic moved away from host port 443
```

---

## 2. Ingress Traffic Redirection Loops (Ingress Rules Layer)

* **The Problem:** Even with ports unblocked, local browser traffic was being redirected into SSL/TLS loops, preventing successful HTTP-based application testing.

* **The Fix:** I disabled the Nginx Ingress controller's automatic SSL redirect behavior by adding annotations to `ingress.yaml`, allowing local HTTP traffic to reach the application without forced HTTPS redirection.

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
```

---

## 3. FastCGI Connection Timeout Drops (Nginx Configuration Tier)

* **The Problem:** During the Moodle installation database population phase, backend PHP execution exceeded the default Nginx timeout thresholds. The reverse proxy terminated long-running requests before database initialization completed.

* **The Fix:** I modified the Nginx server block configuration to increase FastCGI timeout values, allowing long-running Moodle installation and database migration tasks to complete successfully.

```nginx
fastcgi_read_timeout 600s;
fastcgi_send_timeout 600s;
```

---

## 4. The Isolated Container Network Lock (PHP-FPM Topology)


* **The Problem:** Nginx successfully received web traffic, but PHP requests failed when forwarding to PHP-FPM. Investigation showed PHP-FPM was configured to listen only on `127.0.0.1:9000`. Since Nginx and PHP-FPM run in separate containers, PHP-FPM was not reachable through the container network.

* **The Fix:** I validated the issue by modifying the PHP-FPM listener at runtime. After confirming the root cause, I moved the configuration change into the Docker build process so the PHP-FPM network configuration was applied consistently during image creation.

```dockerfile
# Configure PHP-FPM for container network communication
RUN sed -i 's/listen = 127.0.0.1:9000/listen = 9000/g' /usr/local/etc/php-fpm.d/www.conf
```

---

## 5. The HTML Web Page Download Trap (Init Container Storage Pipeline)

* **The Problem:** The Moodle PHP pod became stuck in an `Init:Error` state. Reviewing the initialization container logs showed that the download process retrieved HTML page content instead of the Moodle application archive, causing the extraction process (`tar`) to fail.

* **The Fix:** I updated the `initContainers` configuration in `deployment.yaml` to use the direct Moodle archive URL with redirect handling enabled. I then removed the corrupted Persistent Volume Claim (`moodle-pvc`) so the initialization process could restart with clean storage.


# Fixed: Uses the explicit direct tarball URL with redirect handling
wget --max-redirect=5 -O moodle.tgz "https://download.moodle.org/download.php/direct/stable404/moodle-latest-404.tgz"


---

## 6. The Application Resource Deprivation Barrier (Application Optimization)

* **The Problem:** Inspection of the PHP runtime configuration showed the default container memory allocation was limited to `128M`. Moodle requires additional resources during initial installation to process directory indexing and database table creation.

* **The Fix:** I added a custom PHP configuration override (`moodle.ini`) during the Docker image build process to increase the runtime limits:

```ini
memory_limit=512M
max_execution_time=300
max_input_vars=5000
```

---

## 7. The Hidden Worker Node Redirection (Ingress Routing Scheduling)

## 7. The Hidden Worker Node Redirection (Ingress Routing Scheduling)

* **The Problem:** Every application pod reported healthy, yet browser requests still returned `ERR_EMPTY_RESPONSE`. Investigation showed that Kubernetes had scheduled the `ingress-nginx-controller` pod onto the `lab-worker` node. In the local KinD environment, Windows host port mappings were attached only to the `lab-control-plane` node, causing external traffic to reach a node without the ingress controller.

* **The Fix:** I updated the ingress controller deployment scheduling rules to force the `ingress-nginx-controller` pod onto the control-plane node using a `nodeSelector` and control-plane toleration. This aligned the external traffic entry point with the ingress routing layer.

The issue was caused by traffic entry-point misalignment between the KinD node topology and ingress controller placement, not by application health or pod availability.

```bash
kubectl get pods -n ingress-nginx -o wide -w

kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
-p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'
```
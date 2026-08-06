# Kubernetes Deployment Post-Mortem

Deploying a multi-tier stateful application like Moodle into a local Kubernetes cluster introduced architectural challenges involving networking, storage, initialization, and application configuration. This document captures the troubleshooting process and lessons learned while migrating the Moodle container stack from Docker Compose to a local Kubernetes environment using KinD.

## 1. Local Network Port Conflicts and Host Mappings

* **The Problem:** The cluster flatly refused connections on `localhost`, preventing any initial traffic from reaching the local environment.
* **The Cause:** A process trace revealed that stale background instances of `com.docker.backend.exe` and `wslrelay.exe` were actively holding host ports 80 and 443. Furthermore, the initial KinD configuration attempted to expose secure cluster traffic directly through host port 443, causing an immediate conflict with existing local Windows networking layers.
* **The Fix:** Cleared the stale Docker Desktop and WSL2 networking states using PowerShell and WSL shutdown commands. The KinD cluster was then recreated with an updated configuration that relocated secure web traffic to host port 8443 while keeping core cluster networking isolated.

```yaml
hostPort: 80          # HTTP traffic
hostPort: 8443        # HTTPS traffic moved away from host port 443
```

---

## 2. Ingress Traffic Redirection Loops

* **The Problem:** Local web browser traffic became trapped in continuous SSL/TLS redirection loops, which blocked all HTTP-based application testing.
* **The Cause:** The Nginx Ingress controller was enforcing default global configurations that automatically upgraded all incoming unencrypted HTTP requests to secure HTTPS connections.
* **The Fix:** Explicitly disabled the Ingress controller's automatic SSL redirect behaviors by injecting specific configuration annotations directly into the application's Ingress resource manifest.

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
```

---

## 3. FastCGI Connection Timeout Drops

* **The Problem:** The Nginx reverse proxy prematurely terminated long-running backend requests, causing the deployment to fail midway through execution.
* **The Cause:** During the Moodle installation database population phase, backend PHP execution times exceeded the default Nginx timeout thresholds. This caused the proxy to drop the connection before database initialization could finish.
* **The Fix:** Modified the Nginx server block configuration to drastically increase the FastCGI read and send timeout limits, allowing heavy database schema migrations to complete uninterrupted.

```nginx
fastcgi_read_timeout 600s;
fastcgi_send_timeout 600s;
```

---

## 4. Isolated Container Network Lock

* **The Problem:** Nginx successfully received web traffic from the Ingress layer but failed to forward any PHP requests to the underlying processing engine.
* **The Cause:** The PHP-FPM process was natively configured to listen strictly on the local loopback address (`127.0.0.1:9000`). Because Nginx and PHP-FPM operate in separate isolated containers, PHP-FPM was unreachable across the shared container network.
* **The Fix:** Updated the core PHP-FPM configuration via a runtime stream editor command during the Docker image build process to ensure the engine binds to all network interfaces.

```dockerfile
# Configure PHP-FPM for container network communication
RUN sed -i 's/listen = 127.0.0.1:9000/listen = 9000/g' /usr/local/etc/php-fpm.d/www.conf
```

---

## 5. Init Container Storage Pipeline Corruption

* **The Problem:** The Moodle PHP application pod became permanently trapped in an `Init:Error` lifecycle state.
* **The Cause:** Logs from the initialization container revealed that the download process was fetching standard HTML error page content instead of the actual Moodle application archive. This corrupted source material caused subsequent tape archive (`tar`) extraction commands to fail.
* **The Fix:** Updated the initialization container configuration inside the deployment manifest to target an explicit, direct tarball URL with redirect tracking enabled. The corrupted Persistent Volume Claim (`moodle-pvc`) was then purged to give the initialization engine a clean slate.

```yaml
# Deployment manifest initContainers command update
command: ["sh", "-c", "wget --max-redirect=5 -O moodle.tgz 'https://moodle.org' && tar -xzf moodle.tgz"]
```

---

## 6. Moodle Installation Resource Limits

* **The Problem:** The Moodle installation repeatedly locked up or failed during the initial setup phase despite healthy network connectivity and running containers.
* **The Cause:** The default PHP container configuration limited available resources, including a 128M memory limit. This was insufficient for Moodle's initial installation process, which performs intensive operations such as file processing and database schema creation.
* **The Fix:** Added a custom PHP configuration override (`moodle.ini`) to the Docker image to increase runtime limits:

```ini
memory_limit=512M
max_execution_time=300
max_input_vars=5000
```

---

## 7. Hidden Worker Node Redirection and Ingress Scheduling

* **The Problem:** External browser communication to the Moodle application failed with an `ERR_EMPTY_RESPONSE` error, even though all Kubernetes application pods reported healthy status and Moodle data remained accessible. The issue was isolated to the external traffic path between the Windows host and the Kubernetes Ingress layer.
* **The Cause:** The cluster was configured as a multi-node KinD environment instead of the default single-node setup. The traffic path and ingress controller placement were misaligned between the control-plane and worker nodes, causing external requests to reach a node that was not handling Ingress traffic.
* **The Fix:** A temporary diagnostic hotfix was applied by patching the `ingress-nginx-controller` deployment with scheduling rules to move the controller onto the node receiving external traffic. This confirmed that the issue was related to Ingress placement and node networking rather than the Moodle application, Kubernetes services, or persistent storage.

```bash
kubectl get pods -n ingress-nginx -o wide -w
```

The hotfix:
```bash
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
-p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}}}'
```

## 8. Ingress Controller Scheduling Issue (Permanent Fix)

* **The Problem:** The initial KinD cluster configuration placed the ingress entry point on the control-plane node. The control-plane node had the `ingress-ready=true` label and the required host port mappings, allowing external traffic to enter through the control-plane node.
* **The Cause:** The ingress-nginx deployment included tolerations for the control-plane taint, allowing the ingress controller to schedule on the control-plane node. In a multi-node KinD cluster, this caused the ingress controller placement and external traffic entry point to rely on the control-plane configuration.
* **The Fix:** The ingress configuration was updated to move the ingress entry point to the worker node.

kind-config.yaml Changes:
- Removed the `ingress-ready=true` label from the control-plane node.
- Added the `ingress-ready=true` label to the worker node.
- Moved the host port mappings for ports 80 and 443 to the worker node.

ingress-nginx.yaml Changes:
- Removed the control-plane tolerations from the ingress controller deployment.

Validation
The ingress controller was verified running on the worker node:
```bash
kubectl get pods -n ingress-nginx -o wide
```

The ingress controller was verified running on the worker node:
```bash
kubectl get pods -n ingress-nginx -o wide
```

Expected:
```text
NAME                                      NODE
ingress-nginx-controller-xxxxx            lab-worker
```
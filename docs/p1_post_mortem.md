# Infrastructure Migration Post-Mortem

Deploying the infrastructure architecture onto Google Cloud Platform (GCP) from a fresh system account profile introduced several challenges involving Terraform state management, project authorization, IAM permissions, shell environment context, and deployment configuration.
---

## 1. Terraform State File Conflicts

* **The Problem:** Running `terraform plan` returned a `403 Forbidden` error. Terraform was referencing an older GCP project environment (`cloud-lab-XXXXX`) that was no longer part of the active configuration.

* **The Cause:** Although the previous project ID had been removed from the Terraform configuration files, local Terraform state and initialization data from the previous environment were still present. Terraform used this existing state information during execution, causing resources to be evaluated against the incorrect project context.

* **The Fix:** Removed the local Terraform state and initialization files to force a clean Terraform initialization:
```bash
rm -rf .terraform/
rm -f terraform.tfstate terraform.tfstate.backup
```
---


## 2. GCP Environment Context Issues

* **The Problem:** After transitioning to a different GCP environment and project, `gcloud` commands continued referencing the previous project configuration.

* **The Cause:** Local environment variables (`CLOUDSDK_CORE_PROJECT` and `GOOGLE_PROJECT`) remained set from the previous environment and overrode the updated `gcloud` project configuration.

* **The Fix:** Cleared the outdated environment variables, updated the active GCP project context, and validated the configuration before continuing deployment.

Remove old project overrides from the current shell session.
```bash
unset CLOUDSDK_CORE_PROJECT
unset GOOGLE_PROJECT
```

Set the intended GCP project for this session.
```bash
export GOOGLE_PROJECT="<PROJECT_ID>"
export CLOUDSDK_CORE_PROJECT="<PROJECT_ID>"
```

Verify intended active gcloud project configuration.
```bash
gcloud config get-value project
```

Verify authenticated as the correct Google account.
```bash
gcloud config get-value account
```

---

## 3.GCP Project Activation Issues

* **The Problem:** Terraform deployment failed with a `403 Forbidden` error because the active GCP project was suspended:
```text
googleapi: Error 403: Consumer 'projects/<PROJECT_ID>' has been suspended.
```

* **The Cause:** The target GCP project was not ready for resource deployment. The project billing status and configuration needed to be validated before Terraform could create resources.

* **The Fix:** Verified the project billing configuration and linked an active billing account to the GCP project:
```bash
gcloud billing projects link <PROJECT_ID> --billing-account=<BILLING_ACCOUNT_ID>
```

---

## 4. IAM Permission Validation

* **The Problem:** After correcting the project context, Terraform failed while creating network resources with a critical `403 Permission Denied` error:
```text
Error creating Firewall: googleapi: Error 403: Permission denied on resource project <PROJECT_ID>
```

* **The Cause:** The authenticated account did not have the required permissions to create Compute Engine networking resources in the target GCP project. 

* **The Fix:** Updated the project IAM permissions and refreshed the local authentication credentials:
```bash
gcloud projects add-iam-policy-binding <PROJECT_ID> \
    --member="user:<ACCOUNT_EMAIL>" \
    --role="roles/compute.admin"
```

Refresh local Application Default Credentials (ADC)
```bash
gcloud auth application-default login
```

Application Default Credentials (ADC) allow tools such as Terraform and Google Cloud SDK integrations to authenticate API requests using the configured user identity.

---

## 5. Shell Command Formatting and Multi-Line Input Issues

* **The Problem:** While enabling GCP services, the command execution failed with an `AUTH_PERMISSION_DENIED` / `SERVICE_CONFIG_NOT_FOUND_OR_PERMISSION_DENIED` error. The error output showed that the service name was being interpreted incorrectly due to a malformed command argument.

* **The Cause:** A multi-line command copied into the terminal was not parsed correctly. The line continuation characters (`\`) caused the command input to split incorrectly, resulting in an invalid service name being passed to the `gcloud` command.

* **The Fix:** I simplified the command execution by separating multi-line commands into individual single-line commands, ensuring each service activation request was processed correctly.

```bash
gcloud services enable compute.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

---


## 6. Moodle Administrator Setup

* **The Problem:** The Moodle web installer timed out during the final administrator account setup wizard and returned an `invalidsesskey` token error:
```text
error/moodle/invalidsesskey
```

* **The Cause:** The administrator account page failed to complete through the browser session, preventing the installation wizard from finishing. This was an interface-level session tracking dropout, meaning the database schema initialization had already completed successfully behind the scenes.

* **The Fix:** Completed the remaining administrator account profile configuration using Moodle's built-in CLI tools directly inside the running PHP-FPM container:

Identify the PHP-FPM container name:
```bash
docker ps
```

Update the administrator account password using Moodle CLI tools:
```bash
docker exec -it docker_php-fpm_1 php /var/www/html/admin/cli/reset_password.php --username=admin
```

Flush the broken security tokens out of the session backend cache:
```bash
docker exec -it docker_php-fpm_1 php /var/www/html/admin/cli/purge_caches.php
```

---

## 7. Moodle Slash Arguments and Nginx Configuration

* **The Problem:** Uploaded Moodle resources, including site images and course files, completely failed to render correctly across the user interface.

* **The Cause:** Moodle uses slash arguments when serving files out of its storage directories. The Nginx PHP configuration block was not correctly capturing or passing the required `PATH_INFO` metadata variables down to the PHP-FPM processing engine.

* **The Fix:** Updated the Nginx PHP location configuration block to explicitly extract and include the required FastCGI parameters:

```nginx
location ~ [^/]\.php(/|\$) {
    fastcgi_split_path_info ^(.+\.php)(/.+)\$;
    
    include fastcgi_params;
    fastcgi_pass php-fpm:9000;
    
     fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_path_info;
}
```

---

## 8. Cloud VM Nginx Server Configuration

* **The Problem:** Moodle was not responding correctly when accessed through the Google Cloud VM external IP address.

* **The Cause:** The Nginx configuration used the local development setting:
```nginx
server_name localhost;
```

* **The Fix:** Updated the Nginx server configuration for the deployment environment. 

Catch-All Wildcard (Immune to Ephemeral IP Changes):
```nginx
server_name _;
```
or
Explicit Binding (Requires Updating if the Cloud IP Rotates):
```nginx
server_name 34.xxx.xx.xxx;
``` 

For production deployments using a registered domain name and HTTPS:
```nginx
server_name moodle.company.com;
```
---

# Lessons Learned and Future Validation

The Moodle CLI tools provided an effective administrative recovery method when the web-based installation workflow could not complete. However, this was a recovery procedure and not a replacement for correcting the deployment architecture.

Production deployments should avoid relying on direct IP-based access and instead use a stable hostname with HTTPS termination. The application URL, reverse proxy configuration, TLS settings, and external access path must remain consistent to ensure proper session validation.

The Phase 3 Kubernetes deployment on Google Cloud Platform will be used to compare the behavior of the workload under a production-style architecture, including Kubernetes ingress, HTTPS, and domain-based access. The deployment will validate whether the `invalidsesskey` behavior was related to the external URL/security boundary introduced during the Docker Compose GCP deployment or was specific to the original deployment configuration.

# Security Policy

## Security Measures in this Image

This image is built with a "Security-First" mindset to protect both the game server data and the host system.

1. **Non-Root Execution**: The container runs as the `container` user (UID 1000) by default. Even if an attacker gains control of the Hytale process, they do not have root access to the container or the host.

2. **Zombie Process Protection**: We use `tini` as the init system. This ensures that the Java process is managed correctly, signals (like `SIGTERM`) are handled gracefully, and "zombie" processes are reaped to prevent resource exhaustion.

3. **Audit Scripts**: The image includes pre-flight audit scripts (`security.sh`, `network.sh`, `prod.sh`) that run on every boot to detect common misconfigurations before the server starts. Enable with `DEBUG=TRUE` or `PROD=TRUE`.

4. **Minimal Attack Surface**: Based on `eclipse-temurin` (JRE), we exclude unnecessary build tools, compilers, and shells where possible to reduce the footprint for potential exploits.

5. **Read-Only Integrity**: Critical scripts are stored with appropriate permissions to prevent runtime modification.

6. **Input Validation**: Environment variables are validated before being applied to configuration files. Invalid JSON is backed up rather than corrupted.

7. **No Secrets in Images**: OAuth tokens and credentials are stored in the mounted volume, not baked into the image.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| alpine  | :white_check_mark: |
| ubuntu  | :white_check_mark: |
| alpine-liberica | :white_check_mark: |

## Reporting a Vulnerability

**Please follow these steps to report security issues:**

* **Submit a Private Advisory**: Report security issues via [GitHub Security Advisories](https://github.com/shotah/hytale-server-container/security/advisories/new).

* **Alert the Maintainer**: Create an empty security issue to alert us, as GitHub Advisories do not send notifications: [Submit Alert Issue](https://github.com/shotah/hytale-server-container/issues/new?assignees=&labels=security&template=security_alert.md).

* **Proof of Concept Required**: Do not report upstream dependency issues or automated scan results unless you have a **Proof of Concept (PoC)** demonstrating the issue affects this specific image.

* **Keep it Private**: Do not use the public issue tracker or discuss vulnerabilities publicly until a fix is released.

## Best Practices for Deployment

### 1. Resource Limits (DoS Protection)

Always run this container with memory and CPU limits to prevent a rogue process from crashing your host.

**Docker Compose:**
```yaml
services:
  hytale:
    image: shotah/hytale-server:alpine
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          memory: 2G
```

**Docker CLI:**
```bash
docker run --memory=4g --cpus=2 shotah/hytale-server:alpine
```

### 2. Network Isolation

* **Avoid `--network host`** unless absolutely necessary. Use the default bridge or a custom Docker network.
* Only expose the necessary port: `5520/udp` for Hytale game traffic.
* Consider a reverse proxy for additional protection on public servers.

### 3. Filesystem Security

* Mount your local volume to `/home/container`.
* Ensure the host directory is owned by UID `1000` to match the container user:
  ```bash
  sudo chown -R 1000:1000 ./data
  ```
* Use appropriate permissions (`755` for directories, `644` for files).

### 4. Authentication Security

* OAuth tokens are stored in `~/.hytale/` within the container volume.
* Never share or commit your `data/` folder containing auth tokens.
* Use `.gitignore` to exclude sensitive files if your config is in version control.

### 5. Password Protection

For private servers, always set a strong password:
```yaml
environment:
  HYTALE_PASSWORD: "your-strong-password-here"
  HYTALE_WHITELIST_ENABLED: "true"
```

### 6. Keep Images Updated

We regularly rebuild this image to include the latest JRE security patches. Enable automated updates or periodically pull the latest tag:

```bash
docker pull shotah/hytale-server:alpine
```

Or use Watchtower for automatic updates:
```yaml
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400 hytale-server
```

## Security Checklist

Before going to production, verify:

- [ ] Container runs with resource limits
- [ ] Not using `--network host`
- [ ] Volume permissions set correctly (UID 1000)
- [ ] Strong password set (if public-facing)
- [ ] Whitelist enabled (if private server)
- [ ] Auth tokens not committed to version control
- [ ] Using latest image version
- [ ] `PROD=TRUE` enabled for production checks

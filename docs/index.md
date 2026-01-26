---
layout: default
title: 🏠 Home
nav_order: 1
description: "Hytale Docker Server Documentation Home"
permalink: /
---

# 🐳 Hytale Docker Server

Welcome to the official documentation for the **`shotah/hytale-server`**. This project provides a high-performance, containerized environment for hosting Hytale servers with ease, featuring automated binary management cross-platform and Pterodactyl support.

To get the most performance out of your server, I suggest taking a look at the [optimizations](./optimizations.md) page!

---

## ✨ Key Features

* **🚀 Fast server startup:** Startup your server in 7 seconds with `CACHE=TRUE`
* **⚡ Easy Deployment:** Go to the installation pages to get started
* **🤖 Smart CLI:** Includes the `hytale-downloader` tool to manage server binaries and check for updates automatically. You can just use "hytale-downloader" in the terminal to accecs it.
* **🍓 Multi-Arch Support:** Optimized for `x86_64` (`ARM64` coming soon [more info](https://x.com/slikey/status/2010869532454510999)).
* **🛠️ Diagnostic Suite:** Built-in debug mode to audit your network and security settings automatically.
* **📉 Slim Images:** Optimized, lightweight image variants for production environments.

---

## 🚀 Getting Started

Ready to host your world? Follow our step-by-step guides to get started:

1.  **[Requirements](./installation/requirements.md):** Hytale game license necessary.
2.  **[System Requirements](./installation/system_requirements.md):** Check if your hardware is ready.
3.  **[Container Installation](./installation/container_installation.md):** Deploy your first server using CLI or Compose.
4.  **[Running the server](./installation/running_container.md):** Explanation how to run the setup and run the hytale server.
5.  **[Debug](./installation/debug.md):** Learn how to debug your installation.
6.  **[Support](./installation/support.md.md):** Is your installation not working?
7.  **[Optimizations](./optimizations.md):** Want to go fast? Read here about all the optimizations.

---

## 📚 Examples

Ready-to-use Docker Compose configurations for common setups:

| Example | Description |
|---------|-------------|
| [Basic Server](https://github.com/shotah/hytale-server-container/tree/main/examples/docker-compose) | Minimal configuration to get started |
| [CurseForge Mods](https://github.com/shotah/hytale-server-container/tree/main/examples/curseforge-mods) | Auto-download mods from CurseForge |
| [Pre-release](https://github.com/shotah/hytale-server-container/tree/main/examples/pre-release) | Run the latest pre-release server |
| [Private Server](https://github.com/shotah/hytale-server-container/tree/main/examples/private-server) | Password + whitelist protected |
| [Full-Featured](https://github.com/shotah/hytale-server-container/tree/main/examples/full-featured) | All environment variables documented |

Browse all examples in the [examples folder](https://github.com/shotah/hytale-server-container/tree/main/examples).

---

## 🆘 Need Help?

If you run into trouble, we have resources available:

* **[Frequently Asked Questions](./faq.md):** Common fixes for connection and time-zone issues.
* **[GitHub Issues](https://github.com/shotah/hytale-server-container/issues):** Report bugs or request new features.
* **[Discussions](https://discord.gg/M8yrdnHb32):** Connect with other Hytale server owners.

---

---

## 🙏 Credits & Acknowledgments

This project is a fork of the excellent work by **[deinfreu](https://github.com/deinfreu)**:

| | |
|---|---|
| **Original Repository** | [deinfreu/hytale-server-container](https://github.com/deinfreu/hytale-server-container) |
| **Original Author** | [@deinfreu](https://github.com/deinfreu) |
| **Contributors** | [View all contributors](https://github.com/deinfreu/hytale-server-container/graphs/contributors) |

Thank you to deinfreu and the original contributors for building this container's foundation!

---

> **Disclaimer:** This project is not affiliated with HYPIXEL STUDIOS CANADA INC. A valid Hytale license is required to download the server binaries.
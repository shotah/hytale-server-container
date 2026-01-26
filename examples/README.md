# Docker Compose Examples

Ready-to-use configurations for different server setups.

## Available Examples

| Example | Description |
|---------|-------------|
| [docker-compose](docker-compose/) | Basic server with minimal config |
| [curseforge-mods](curseforge-mods/) | Auto-download mods from CurseForge |
| [pre-release](pre-release/) | Run the latest pre-release server |
| [private-server](private-server/) | Password + whitelist protected |
| [full-featured](full-featured/) | All environment variables documented |

## Quick Start

```bash
cd examples/docker-compose
docker-compose up
```

## Finding Your Player UUID

To whitelist players or grant OP, you need their UUID. You can find it:
1. From [hytaleid.com](https://hytaleid.com/) - lookup by username
2. In the server logs when they connect
3. In the `permissions.json` file after they've connected once

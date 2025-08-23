# GitHub Actions Docker Build

This repository includes a GitHub Actions workflow to automatically build and push Docker images to GitHub Container Registry (GHCR).

## Setup

The workflow uses **GitHub Container Registry (GHCR)** which is:

- ✅ Free for public repositories
- ✅ Integrated with GitHub (no additional setup required)
- ✅ Uses GitHub token automatically

## How it Works

### Branch Name to Image Tag Mapping

The workflow automatically converts branch names to Docker image names and tags:

| Branch Name | Image Name | Tag | Example |
|-------------|------------|-----|---------|
| `main` | `ghcr.io/brandli/setups` | `main` + `latest` | `ghcr.io/brandli/setups:main` |
| `feature/auth` | `ghcr.io/brandli/setups` | `feature-auth` | `ghcr.io/brandli/setups:feature-auth` |
| `ocb/multi-stage` | `ghcr.io/brandli/setups` | `ocb-multi-stage` | `ghcr.io/brandli/setups:ocb-multi-stage` |
| `myapp/v1.2.3` | `ghcr.io/brandli/myapp` | `v1.2.3` | `ghcr.io/brandli/myapp:v1.2.3` |

### Special Branch Format: `name/tag`

If your branch name contains a slash (`/`), the workflow will:

- Use the part before the slash as the **image name**
- Use the part after the slash as the **tag**

Examples:

- Branch `ocb/18.0` → Image `ghcr.io/brandli/ocb:18.0`
- Branch `myapp/latest` → Image `ghcr.io/brandli/myapp:latest`
- Branch `api/v2.1` → Image `ghcr.io/brandli/api:v2.1`

## Using the Images

### Pull from GitHub Container Registry

```bash
# Pull the latest main branch build
docker pull ghcr.io/brandli/setups:main

# Pull a specific branch build
docker pull ghcr.io/brandli/setups:ocb-multi-stage

# Pull using name/tag format
docker pull ghcr.io/brandli/ocb:18.0
```

### Authentication for Private Repositories

If your repository is private, you need to authenticate:

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Then pull
docker pull ghcr.io/brandli/setups:main
```

## Workflow Triggers

The workflow runs on:

- ✅ **Push to any branch** - Builds and pushes image
- ✅ **Pull requests to main** - Builds image (but doesn't push)

## Build Details

- **Target**: `development` stage from your multi-stage Dockerfile
- **Cache**: Uses GitHub Actions cache for faster builds
- **Labels**: Includes metadata about the build
- **Platforms**: Currently builds for `linux/amd64`

## Repository Settings

No additional setup required! The workflow uses:

- `GITHUB_TOKEN` (automatically provided)
- Repository must have "Write" permissions for packages (usually enabled by default)

The images will appear in the "Packages" section of your GitHub repository.

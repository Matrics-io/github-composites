# Update Kustomize Image Digests from Google Artifact Registry

This GitHub Action updates image digests in kustomization files by checking Google Artifact Registry for the latest digests and pushing changes directly to the main branch.

## Features

- 🎯 **Simple and focused** - Specifically designed for Google Artifact Registry
- 📝 **Direct image input** - Pass images as YAML input, no file reading required
- 🔍 **Auto-detects digests** - Gets latest digests from GAR for specified images
- 🔄 **Always updates** - Sets images to use latest available digests
- 🐳 **Docker-native** - Uses Docker commands, no gcloud SDK required
- 🛠️ **Pure bash** - Clean, readable bash script following GitHub Actions best practices
- ⚡ **Direct push** - Commits and pushes directly to main branch
- 🔐 **Flexible auth** - Use existing authentication actions

## Quick Start

```yaml
name: Update Image Digests
on:
  schedule:
    - cron: '0 */6 * * *'  # Check every 6 hours
  workflow_dispatch:

jobs:
  update-digests:
    runs-on: ubuntu-latest
    steps:
      - name: Docker Login to Google Artifact Registry
        uses: 91Life/github-composites/docker-login-build-push@main
        with:
          google-credentials: ${{ secrets.GOOGLE_CREDENTIALS }}
          google-region: us-central1
          # Other docker login parameters

      - name: Update kustomization digests
        uses: 91Life/github-composites/update-kustomize-image-tag@main
        with:
          repository: 'your-org/k8s-configs'
          token: ${{ secrets.GITHUB_TOKEN }}
          target-kustomization-path: 'overlays/production'
          google-region: 'us-central1'
          repository-name: 'your-artifact-repo'
          images: |
            stats: mirror.gcr.io/hardcoreeng/stats:v1.4
            workspace: mirror.gcr.io/hardcoreeng/workspace:v1.4
            nginx: nginx:latest
```

## How It Works

1. **Requires Authentication** - Users must authenticate with GAR before using this action
2. **Checks Out Repository** - Automatically clones the target repository using `actions/checkout`
3. **Parses Images Input** - Reads the simplified YAML images configuration from input
4. **Checks GAR for Digests** - Uses `docker manifest inspect` to get latest digests for each image
5. **Updates Kustomization** - Modifies the target repository's kustomization files with latest digests
6. **Commits and Pushes** - Commits changes directly to main branch

## Authentication

This action **does not handle authentication**. You must authenticate with Google Artifact Registry before using this action. You can use:

### Option 1: Use the docker-login-build-push action (recommended)
```yaml
- name: Docker Login to GAR
  uses: 91Life/github-composites/docker-login-build-push@main
  with:
    google-credentials: ${{ secrets.GOOGLE_CREDENTIALS }}
    google-region: us-central1
    push: false  # We only need login, not push
```

### Option 2: Use docker/login-action directly
```yaml
- name: Docker Login to GAR
  uses: docker/login-action@v3
  with:
    registry: us-central1-docker.pkg.dev
    username: _json_key
    password: ${{ secrets.GOOGLE_CREDENTIALS }}
```

## Images Input Format

The `images` input accepts a direct YAML structure where each key is the image name in your kustomization, and the value is the full image reference with tag:

```yaml
image-name-in-kustomization: full/registry/path/image-name:tag
```

### Examples:

**Simple format:**
```yaml
stats: mirror.gcr.io/hardcoreeng/stats:v1.4
workspace: mirror.gcr.io/hardcoreeng/workspace:v1.4
nginx: nginx:latest
redis: redis:7-alpine
```

**Mixed registries:**
```yaml
app: us-central1-docker.pkg.dev/my-project/my-repo/app:v1.0.0
nginx: nginx:latest
postgres: postgres:15-alpine
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `repository` | Target repository (`owner/repo`) | ✅ | - |
| `token` | GitHub token with repository access | ✅ | - |
| `images` | YAML string of images in format: `name: image:tag` | ✅ | - |
| `target-kustomization-path` | Path to target kustomization directory | ✅ | `.` |
| `google-region` | Google region for Artifact Registry | ✅ | `us-central1` |
| `repository-name` | Artifact Registry repository name | ✅ | - |
| `commit-message` | Commit message | ❌ | `Update image digests from Google Artifact Registry` |

## Outputs

| Output | Description |
|--------|-------------|
| `updated-images` | JSON array of updated images with digests |
| `changes-made` | Boolean indicating if any changes were made |

## Setup Requirements

### 1. Google Service Account

Create a service account with Artifact Registry Reader permissions:

```bash
gcloud iam service-accounts create artifact-registry-reader \
    --description="For GitHub Actions to read Artifact Registry" \
    --display-name="AR Reader"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:artifact-registry-reader@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"

gcloud iam service-accounts keys create ~/key.json \
    --iam-account=artifact-registry-reader@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### 2. GitHub Secrets

Add these secrets to your repository:
- `GOOGLE_CREDENTIALS` - The JSON content of your service account key  
- `GITHUB_TOKEN` - For repository access (usually automatic)

## Advanced Examples

### Complete Workflow with Authentication

```yaml
name: Update Image Digests
on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:

jobs:
  update-digests:
    runs-on: ubuntu-latest
    steps:
      - name: Authenticate with GAR
        uses: 91Life/github-composites/docker-login-build-push@main
        with:
          google-credentials: ${{ secrets.GOOGLE_CREDENTIALS }}
          google-region: us-central1
          push: false

      - name: Update image digests
        uses: 91Life/github-composites/update-kustomize-image-tag@main
        with:
          repository: 'your-org/k8s-configs'
          token: ${{ secrets.GITHUB_TOKEN }}
          target-kustomization-path: 'overlays/production'
          google-region: 'us-central1'
          repository-name: 'your-artifact-repo'
          images: |
            workspace: mirror.gcr.io/hardcoreeng/workspace:v1.4
            transactor: mirror.gcr.io/hardcoreeng/transactor:v2.1
```

### Multi-Environment Updates

```yaml
strategy:
  matrix:
    environment: [staging, production]
    include:
      - environment: staging
        images: |
          app: my-registry/app:develop
          worker: my-registry/worker:develop
      - environment: production
        images: |
          app: my-registry/app:v1.0.0
          worker: my-registry/worker:v1.0.0

steps:
  - name: Authenticate with GAR
    uses: docker/login-action@v3
    with:
      registry: us-central1-docker.pkg.dev
      username: _json_key
      password: ${{ secrets.GOOGLE_CREDENTIALS }}

  - name: Update ${{ matrix.environment }}
    uses: 91Life/github-composites/update-kustomize-image-tag@main
    with:
      repository: 'your-org/k8s-configs'
      target-kustomization-path: 'overlays/${{ matrix.environment }}'
      images: ${{ matrix.images }}
      # ... other inputs
```

### Dynamic Image Generation

```yaml
- name: Authenticate with GAR
  uses: docker/login-action@v3
  with:
    registry: us-central1-docker.pkg.dev
    username: _json_key
    password: ${{ secrets.GOOGLE_CREDENTIALS }}

- name: Generate images config
  id: images
  run: |
    IMAGES=$(cat << EOF
    app: ${{ env.REGISTRY }}/app:${{ github.sha }}
    worker: ${{ env.REGISTRY }}/worker:${{ github.sha }}
    EOF
    )
    echo "images<<EOF" >> $GITHUB_OUTPUT
    echo "$IMAGES" >> $GITHUB_OUTPUT
    echo "EOF" >> $GITHUB_OUTPUT

- name: Update kustomization
  uses: 91Life/github-composites/update-kustomize-image-tag@main
  with:
    images: ${{ steps.images.outputs.images }}
    # ... other inputs
```

### Using Outputs

```yaml
- name: Update digests
  id: update
  uses: 91Life/github-composites/update-kustomize-image-tag@main
  with:
    # ... inputs

- name: Notify on changes
  if: steps.update.outputs.changes-made == 'true'
  run: |
    echo "Updated images:"
    echo '${{ steps.update.outputs.updated-images }}' | jq -r '.[] | "- \(.name): \(.imageRef)@\(.digest[0:12])..."'
```

## Benefits for GitOps

- **Automated Security Updates** - Automatically use latest image digests
- **Consistent Deployments** - Ensure all environments use specific, verified image versions
- **Audit Trail** - Clear history of what changed and when via Git commits
- **No Manual Intervention** - Fully automated pipeline from version specification to deployment
- **Lightweight** - Pure bash, no heavy dependencies or runtimes
- **Simple Integration** - Direct push to main, no PR overhead
- **Flexible Authentication** - Use existing authentication patterns

## Troubleshooting

**"Could not get digest for image"**
- Verify you're authenticated with GAR (check previous authentication step)
- Verify the image exists in your Artifact Registry
- Ensure the repository name and region are correct
- Verify the tag exists for the specified image

**"No kustomization file found"**
- Verify the `target-kustomization-path` is correct
- Ensure `kustomization.yaml` or `kustomization.yml` exists

**"Authentication failed" or "permission denied"**
- Ensure you have an authentication step before this action
- Check your Google service account key is valid and properly formatted JSON
- Verify the service account has Artifact Registry Reader role

**"No valid images found in input"**
- Verify your images YAML has the correct structure
- Ensure proper YAML indentation

## Development

The action consists of:
- `action.yaml` - Action definition and metadata
- `update-digests.sh` - Main bash script with all logic

To test locally:
```bash
# Authenticate with Docker first
docker login us-central1-docker.pkg.dev

# Set environment variables
export INPUT_REPOSITORY="your-org/your-repo"
export INPUT_TOKEN="your-token"
export INPUT_IMAGES="app: my-registry/app:v1.0.0
worker: my-registry/worker:v1.0.0"
# ... other inputs

# Run the script
./update-digests.sh
```
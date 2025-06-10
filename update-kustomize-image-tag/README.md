# Update Kustomize Images

This GitHub Action updates images in kustomization files by setting them to specified image references and pushing changes directly to the target branch.

## Features

- 🎯 **Simple and focused** - Just sets images in kustomization files as specified
- 📝 **Direct image input** - Pass images as YAML input
- 🔄 **Direct updates** - Sets images exactly as provided in input
- 🛠️ **Pure bash** - Clean, readable bash script following GitHub Actions best practices
- ⚡ **Direct push** - Commits and pushes directly to target branch
- 🔐 **No auth required** - Uses GitHub token only

## Quick Start

```yaml
name: Update Images
on:
  workflow_dispatch:

jobs:
  update-images:
    runs-on: ubuntu-latest
    steps:  
      - name: Update kustomization images
        uses: 91Life/github-composites/update-kustomize-image-tag@main
        with:
          repository: 'your-org/k8s-configs'
          branch: 'main'
          token: ${{ secrets.GITHUB_TOKEN }}
          kustomization-path: 'overlays/production'
          images: |
            stats: mirror.gcr.io/hardcoreeng/stats:v1.4
            workspace: mirror.gcr.io/hardcoreeng/workspace:v1.4
            nginx: nginx:latest
```

## How It Works

1. **Checks Out Repository** - Automatically clones the target repository using `actions/checkout`
2. **Parses Images Input** - Reads the YAML images configuration from input
3. **Updates Kustomization** - Uses `kustomize edit set image` to set each image as specified
4. **Commits and Pushes** - Commits changes directly to target branch

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
| `branch` | Target branch to update | ✅ | `main` |
| `token` | GitHub token with repository access | ✅ | - |
| `images` | YAML string of images in format: `name: image:tag` | ✅ | - |
| `kustomization-path` | Path to target kustomization directory | ✅ | `.` |
| `commit-message` | Commit message | ❌ | `Update image ` |

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
  - name: Update ${{ matrix.environment }}
    uses: 91Life/github-composites/update-kustomize-image-tag@main
    with:
      repository: 'your-org/k8s-configs'
      branch: 'main'
      token: ${{ secrets.GITHUB_TOKEN }}
      kustomization-path: 'overlays/${{ matrix.environment }}'
      images: ${{ matrix.images }}
```

### Dynamic Image Generation

```yaml
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
    repository: 'your-org/k8s-configs'
    branch: 'main'
    token: ${{ secrets.GITHUB_TOKEN }}
    images: ${{ steps.images.outputs.images }}
```

### Using Outputs

```yaml
- name: Update images
  id: update
  uses: 91Life/github-composites/update-kustomize-image-tag@main
  with:
    repository: 'your-org/k8s-configs'
    branch: 'main'
    token: ${{ secrets.GITHUB_TOKEN }}
    images: |
      app: my-registry/app:v1.0.0
      worker: my-registry/worker:v1.0.0

- name: Notify on changes
  if: steps.update.outputs.changes-made == 'true'
  run: |
    echo "Updated images:"
    echo '${{ steps.update.outputs.updated-images }}' | jq -r '.[] | "- \(.name): \(.imageRef)"'
```

## Benefits for GitOps

- **Declarative Updates** - Set exact image references as needed
- **Consistent Deployments** - Ensure all environments use specified image versions
- **Audit Trail** - Clear history of what changed and when via Git commits
- **No Manual Intervention** - Fully automated pipeline from specification to deployment
- **Lightweight** - Pure bash, no heavy dependencies or runtimes
- **Simple Integration** - Direct push to target branch, no PR overhead

## Troubleshooting

**"No kustomization file found"**
- Verify the `kustomization-path` is correct
- Ensure `kustomization.yaml` or `kustomization.yml` exists

**"No valid images found in input"**
- Verify your images YAML has the correct structure
- Ensure proper YAML indentation

## Development

The action consists of:
- `action.yaml` - Action definition and metadata
- `update-digests.sh` - Main bash script with all logic

To test locally:
```bash
# Set environment variables
export INPUT_REPOSITORY="your-org/your-repo"
export INPUT_TOKEN="your-token"
export INPUT_IMAGES="app: my-registry/app:v1.0.0
worker: my-registry/worker:v1.0.0"
export INPUT_TARGET_KUSTOMIZATION_PATH="."
export INPUT_COMMIT_MESSAGE="Update images"

# Run the script
./update-digests.sh
```
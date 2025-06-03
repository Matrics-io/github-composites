#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Install required tools
install_tools() {
    log_info "Installing required tools..."

    # Install kustomize
    if ! command -v kustomize &> /dev/null; then
        log_info "Installing kustomize..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
        log_success "Kustomize installed"
    else
        log_success "Kustomize already available"
    fi

    # Install yq
    if ! command -v yq &> /dev/null; then
        log_info "Installing yq..."
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
        log_success "yq installed"
    else
        log_success "yq already available"
    fi
}

# Parse images from input
parse_images() {
    log_info "Parsing images from input..."

    if [[ -z "$INPUT_IMAGES" ]]; then
        log_error "No images provided in input"
        exit 1
    fi

    # Write images to temporary file and parse with yq
    echo "$INPUT_IMAGES" > /tmp/images.yaml

    # Convert to JSON array for processing - direct YAML format
    IMAGES=$(yq e 'to_entries | .[] | {"name": .key, "imageRef": .value}' /tmp/images.yaml -o=json | jq -s '.')

    if [[ "$IMAGES" == "[]" || "$IMAGES" == "null" ]]; then
        log_error "No valid images found in input"
        exit 1
    fi

    local image_count=$(echo "$IMAGES" | jq length)
    log_success "Found $image_count images to check"

    # Log the images for debugging
    echo "$IMAGES" | jq -r '.[] | "  - \(.name): \(.imageRef)"'
}

# Configure git for the repository
configure_git() {
    log_info "Configuring git..."

    # Configure git
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"

    log_success "Git configured"
}

# Get image digest from Google Artifact Registry
get_image_digest() {
    local image_url="$1"

    local digest
    digest=$(docker manifest inspect "$image_url" 2>/dev/null | jq -r '.config.digest' 2>/dev/null || echo "")

    echo "$digest"
}

# Update image digests
update_image_digests() {
    log_info "Updating image digests..."

    local target_kustomization_path="$INPUT_TARGET_KUSTOMIZATION_PATH"

    # Find kustomization file in target directory
    local kustomization_file=""
    if [[ -f "$target_kustomization_path/kustomization.yaml" ]]; then
        kustomization_file="$target_kustomization_path/kustomization.yaml"
    elif [[ -f "$target_kustomization_path/kustomization.yml" ]]; then
        kustomization_file="$target_kustomization_path/kustomization.yml"
    else
        log_error "No kustomization.yaml or kustomization.yml found in $target_kustomization_path"
        exit 1
    fi

    log_info "Target kustomization file: $kustomization_file"

    # Change to target kustomization directory
    cd "$target_kustomization_path"

    local updated_images="[]"
    local changes_made="false"

    # Process each image
    echo "$IMAGES" | jq -c '.[]' | while IFS= read -r image; do
        local image_name
        local image_ref

        image_name=$(echo "$image" | jq -r '.name')
        image_ref=$(echo "$image" | jq -r '.imageRef')

        log_info "Checking $image_name ($image_ref)"

        # Get latest digest
        local latest_digest
        latest_digest=$(get_image_digest "$image_ref")

        if [[ -z "$latest_digest" ]]; then
            log_warning "Could not get digest for $image_ref"
            continue
        fi

        echo "   Latest digest: ${latest_digest:0:16}..."

        # Always update with the latest digest (no comparison with current digest)
        log_info "Setting $image_name to use digest from $image_ref"

        # Update with kustomize - use the full image reference with digest
        kustomize edit set image "$image_name=${image_ref}@${latest_digest}"

        # Add to updated images list
        local updated_image
        updated_image=$(jq -n \
            --arg name "$image_name" \
            --arg imageRef "$image_ref" \
            --arg digest "$latest_digest" \
            '{name: $name, imageRef: $imageRef, digest: $digest}')

        updated_images=$(echo "$updated_images" | jq ". + [$updated_image]")
        changes_made="true"
    done

    # Write outputs to files (since we're in a subshell)
    echo "$updated_images" > /tmp/updated_images.json
    echo "$changes_made" > /tmp/changes_made.txt

    # Return to repo root
    cd ..
}

# Commit and push changes
commit_and_push() {
    local updated_images
    local changes_made

    updated_images=$(cat /tmp/updated_images.json 2>/dev/null || echo "[]")
    changes_made=$(cat /tmp/changes_made.txt 2>/dev/null || echo "false")

    if [[ "$changes_made" != "true" ]]; then
        log_info "No changes to commit"
        echo "updated-images=$updated_images" >> "$GITHUB_OUTPUT"
        echo "changes-made=false" >> "$GITHUB_OUTPUT"
        return 0
    fi

    log_info "Committing changes..."

    # Check if there are actual git changes
    if git diff --quiet && git diff --staged --quiet; then
        log_info "No git changes detected"
        echo "updated-images=$updated_images" >> "$GITHUB_OUTPUT"
        echo "changes-made=false" >> "$GITHUB_OUTPUT"
        return 0
    fi

    # Stage changes
    git add .

    # Create commit message
    local commit_message="$INPUT_COMMIT_MESSAGE"

    if [[ "$updated_images" != "[]" ]]; then
        commit_message="$commit_message

Updated images:"
        echo "$updated_images" | jq -r '.[] | "- \(.name): \(.imageRef)@\(.digest[0:12])..."' >> /tmp/commit_addendum.txt
        commit_message="$commit_message
$(cat /tmp/commit_addendum.txt)"
    fi

    # Commit changes
    git commit -m "$commit_message"
    log_success "Changes committed"

    # Push directly to main
    git push origin HEAD
    log_success "Changes pushed to repository"

    # Set outputs
    echo "updated-images=$updated_images" >> "$GITHUB_OUTPUT"
    echo "changes-made=true" >> "$GITHUB_OUTPUT"

    local num_updated
    num_updated=$(echo "$updated_images" | jq length)
    log_success "Successfully updated $num_updated images"
}

# Main execution
main() {
    log_info "🚀 Starting kustomize digest update process..."

    # Validate inputs
    if [[ -z "$INPUT_REPOSITORY" || -z "$INPUT_TOKEN" || -z "$INPUT_IMAGES" ]]; then
        log_error "Missing required inputs"
        exit 1
    fi

    # Install tools
    install_tools

    # Parse images from input
    parse_images

    # Configure git for the repository
    configure_git

    # Update image digests
    update_image_digests

    # Commit and push changes
    commit_and_push

    log_success "Process completed successfully!"
}

# Run main function
main "$@"

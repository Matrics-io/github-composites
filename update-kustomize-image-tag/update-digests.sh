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

    # Write images to temporary file
    echo "$INPUT_IMAGES" > /tmp/images.yaml

    # Get image count for logging
    local image_count=$(echo "$INPUT_IMAGES" | yq e 'length' -)
    log_success "Found $image_count images to update"
}

# Configure git for the repository
configure_git() {
    log_info "Configuring git..."

    # Configure git
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"

    log_success "Git configured"
}

# Update images in kustomization
update_images() {
    log_info "Updating images in kustomization..."

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

    local updated_count=0

    # Process each image directly from YAML
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local image_name=$(echo "$line" | cut -d'=' -f1)
            local image_ref=$(echo "$line" | cut -d'=' -f2-)

            log_info "Setting $image_name to $image_ref"

            # Update with kustomize
            kustomize edit set image "$line"

            # Track updated images
            echo "$image_name=$image_ref" >> /tmp/updated_images.txt
            ((updated_count++))
        fi
    done < <(echo "$INPUT_IMAGES" | yq e 'to_entries | .[] | .key + "=" + .value' -)

    # Write simple outputs
    echo "$updated_count" > /tmp/updated_count.txt
    if [[ $updated_count -gt 0 ]]; then
        echo "true" > /tmp/changes_made.txt
    else
        echo "false" > /tmp/changes_made.txt
    fi

    # Return to repo root
    cd ..
}

# Commit and push changes
commit_and_push() {
    local updated_count
    local changes_made

    updated_count=$(cat /tmp/updated_count.txt 2>/dev/null || echo "0")
    changes_made=$(cat /tmp/changes_made.txt 2>/dev/null || echo "false")

    if [[ "$changes_made" != "true" ]]; then
        log_info "No changes to commit"
        echo "updated-count=$updated_count" >> "$GITHUB_OUTPUT"
        echo "changes-made=false" >> "$GITHUB_OUTPUT"
        return 0
    fi

    log_info "Committing changes..."

    # Check if there are actual git changes
    if git diff --quiet && git diff --staged --quiet; then
        log_info "No git changes detected"
        echo "updated-count=$updated_count" >> "$GITHUB_OUTPUT"
        echo "changes-made=false" >> "$GITHUB_OUTPUT"
        return 0
    fi

    # Stage changes
    git add .

    # Create commit message
    local commit_message="$INPUT_COMMIT_MESSAGE"

    if [[ -f /tmp/updated_images.txt ]]; then
        commit_message="$commit_message

Updated images:"
        while IFS= read -r line; do
            commit_message="$commit_message
- $line"
        done < /tmp/updated_images.txt
    fi

    # Commit changes
    git commit -m "$commit_message"
    log_success "Changes committed"

    # Push changes
    git push origin HEAD
    log_success "Changes pushed to repository"

    # Set outputs
    echo "updated-count=$updated_count" >> "$GITHUB_OUTPUT"
    echo "changes-made=true" >> "$GITHUB_OUTPUT"

    log_success "Successfully updated $updated_count images"
}

# Main execution
main() {
    log_info "🚀 Starting kustomize image update process..."

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

    # Update images
    update_images

    # Commit and push changes
    commit_and_push

    log_success "Process completed successfully!"
}

# Run main function
main "$@"

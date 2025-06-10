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
        sudo curl -L -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
        log_success "yq installed"
    else
        log_success "yq already available"
    fi
}

# Main execution
main() {
    log_info "🚀 Starting kustomize image update process..."

    # Configure git
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"

    # Install tools
    install_tools

    # Go to kustomization directory
    cd "$INPUT_TARGET_KUSTOMIZATION_PATH"

    log_info "Processing images..."

    # Write input to temp file and process each line
    echo "$INPUT_IMAGES" | while IFS=': ' read -r image_name image_value; do
        if [[ -n "$image_name" && -n "$image_value" ]]; then
            # Clean up any whitespace
            image_name=$(echo "$image_name" | xargs)
            image_value=$(echo "$image_value" | xargs)

            log_info "Setting $image_name to $image_value"
            kustomize edit set image "$image_name=$image_value"
            log_success "Set $image_name"
        fi
    done

    # Commit and push if there are changes
    if ! git diff --quiet; then
        log_info "Committing changes..."
        git add .
        git commit -m "$INPUT_COMMIT_MESSAGE"
        git push origin HEAD
        log_success "Changes pushed"

        echo "changes-made=true" >> "$GITHUB_OUTPUT"
    else
        log_info "No changes detected"
        echo "changes-made=false" >> "$GITHUB_OUTPUT"
    fi

    log_success "Process completed successfully!"
}

# Run main function
main "$@"

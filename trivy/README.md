# Trivy Security Scan Action

A reusable GitHub composite action for running Trivy vulnerability scanner with support for Docker image or filesystem scanning, SARIF output, and CVSS threshold enforcement.

## Features

- 🔍 **Dual Scan Types** - Scan Docker images OR filesystem for vulnerabilities
- 📊 **SARIF Output** - Standardized vulnerability reporting format
- 🛡️ **CVSS Threshold Enforcement** - Fail builds on high-severity vulnerabilities
- 🚀 **Official Trivy Action** - Uses the official Aqua Security Trivy action
- 📦 **Artifact Upload** - Automatic SARIF report upload
- 🔗 **GitHub Security Integration** - Upload results to Security tab
- ⚡ **Fast Execution** - Minimal overhead, direct parameter mapping
- 🎯 **Flexible Configuration** - Customizable for various project needs

## Usage

### Basic Filesystem Scan

```yaml
- name: Trivy Filesystem Scan
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "fs"
```

### Docker Image Scan

```yaml
- name: Trivy Image Scan
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "image"
    image: "your-registry/app:latest"
```

### Complete Configuration Example

```yaml
name: Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  trivy-scan:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myapp:latest .

      - name: Run Trivy Security Scan
        uses: Matrics-io/github-composites/trivy@main
        with:
          scan_type: "image"
          image: "myapp:latest"
          fail_on_cvss: "7.0"
          severity: "HIGH"
          timeout: "30"
          ignore_unfixed: "false"
          vuln_type: "os,library"
          skip_dirs: "node_modules,.git,tmp"
          skip_files: "*.log,*.tmp"
```

### Multiple Scan Types

```yaml
# Filesystem only
- name: Filesystem Vulnerability Scan
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "fs"
    scan_path: "src"
    fail_on_cvss: "7.0"

# Image only
- name: Container Image Scan
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "image"
    image: "nginx:alpine"
    fail_on_cvss: "8.0"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `scan_type` | Type of scan (image or fs) | Yes | `"fs"` |
| `image` | Docker image to scan | No* | `""` |
| `scan_path` | Path to scan for filesystem vulnerabilities | No | `"."` |
| `out_dir` | Directory for generated reports | No | `"reports"` |
| `fail_on_cvss` | Fail if CVSS score >= threshold (0.0-10.0) | No | `"7.0"` |
| `severity` | Minimum severity level (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL) | No | `"UNKNOWN"` |
| `timeout` | Timeout in minutes | No | `"30"` |
| `ignore_unfixed` | Ignore unfixed vulnerabilities | No | `"false"` |
| `vuln_type` | Vulnerability types to scan (os,library) | No | `"os,library"` |
| `format` | Output format (table,json,sarif,template) | No | `"sarif"` |
| `skip_dirs` | Directories to skip (comma-separated) | No | `""` |
| `skip_files` | Files to skip (comma-separated) | No | `""` |
| `upload_sarif` | Upload SARIF to GitHub Security tab | No | `"true"` |

*Required when `scan_type` is `"image"`

## Outputs

The action generates the following artifacts:

### SARIF Reports
- **`trivy.sarif`** - Scan results (filesystem or image)

### Artifacts
- **`trivy-sarif-reports`** - Uploaded SARIF files for download
- **GitHub Security Tab** - Results automatically uploaded to Security tab

## CVSS Threshold Behavior

The action enforces security standards through CVSS threshold checking:

- **`fail_on_cvss: "7.0"`** (default) - Fails on HIGH and CRITICAL vulnerabilities
- **`fail_on_cvss: "4.0"`** - Fails on MEDIUM, HIGH, and CRITICAL vulnerabilities  
- **`fail_on_cvss: "10.0"`** - Never fails (useful for reporting only)

| CVSS Score | Severity | Default Behavior |
|------------|----------|------------------|
| 0.0 - 3.9  | LOW      | ✅ Pass |
| 4.0 - 6.9  | MEDIUM   | ✅ Pass |
| 7.0 - 8.9  | HIGH     | ❌ Fail |
| 9.0 - 10.0 | CRITICAL | ❌ Fail |

## Advanced Configuration

### Different Project Types

#### Node.js Projects
```yaml
- name: Scan Node.js Application
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "fs"
    scan_path: "."
    skip_dirs: "node_modules,.git,dist"
    vuln_type: "os,library"
```

#### Python Projects
```yaml
- name: Scan Python Application
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "fs"
    scan_path: "."
    skip_dirs: "__pycache__,.venv,.git"
    vuln_type: "os,library"
```

#### Docker Applications
```yaml
- name: Build and Scan Docker Image
  run: docker build -t myapp:latest .

- name: Scan Docker Image
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "image"
    image: "myapp:latest"
    fail_on_cvss: "7.0"
```

### Multi-Stage Scanning

```yaml
jobs:
  # Stage 1: Filesystem scan
  fs-scan:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    steps:
      - uses: actions/checkout@v4
      - name: Filesystem Scan
        uses: Matrics-io/github-composites/trivy@main
        with:
          scan_type: "fs"
          fail_on_cvss: "7.0"

  # Stage 2: Image scan (only if filesystem scan passes)
  image-scan:
    needs: fs-scan
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp:latest .
      - name: Image Scan
        uses: Matrics-io/github-composites/trivy@main
        with:
          scan_type: "image"
          image: "myapp:latest"
          fail_on_cvss: "7.0"
```

### Conditional Scanning

```yaml
- name: Check for Dockerfile
  id: check-dockerfile
  run: |
    if [ -f "Dockerfile" ]; then
      echo "has-dockerfile=true" >> $GITHUB_OUTPUT
    fi

- name: Scan Docker Image
  if: steps.check-dockerfile.outputs.has-dockerfile == 'true'
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "image"
    image: "myapp:latest"
```

## Integration Examples

### Matrix Strategy for Multiple Images

```yaml
strategy:
  matrix:
    image: [nginx:alpine, node:18-alpine, python:3.9-slim]
    
steps:
  - name: Scan ${{ matrix.image }}
    uses: Matrics-io/github-composites/trivy@main
    with:
      scan_type: "image"
      image: ${{ matrix.image }}
      out_dir: "trivy-reports-${{ matrix.image }}"
```

### Branch-Specific Thresholds

```yaml
- name: Set CVSS threshold based on branch
  id: set-threshold
  run: |
    if [ "${{ github.ref }}" = "refs/heads/main" ]; then
      echo "cvss-threshold=7.0" >> $GITHUB_OUTPUT
    elif [ "${{ github.ref }}" = "refs/heads/develop" ]; then
      echo "cvss-threshold=8.0" >> $GITHUB_OUTPUT
    else
      echo "cvss-threshold=9.0" >> $GITHUB_OUTPUT
    fi

- name: Run Trivy Scan
  uses: Matrics-io/github-composites/trivy@main
  with:
    scan_type: "fs"
    fail_on_cvss: ${{ steps.set-threshold.outputs.cvss-threshold }}
```

### CI/CD Pipeline Integration

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  security-scan:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    needs: test
    steps:
      - uses: actions/checkout@v4
      
      # Filesystem scan
      - name: Filesystem Security Scan
        uses: Matrics-io/github-composites/trivy@main
        with:
          scan_type: "fs"
          fail_on_cvss: "7.0"
      
      # Build and scan image
      - name: Build Docker Image
        run: docker build -t myapp:latest .
      
      - name: Container Security Scan
        uses: Matrics-io/github-composites/trivy@main
        with:
          scan_type: "image"
          image: "myapp:latest"
          fail_on_cvss: "7.0"
          upload_sarif: "false"  # Disable Security tab upload if not enabled

  deploy:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to Production
        run: echo "Deploying..."
```

## Testing Vulnerability Detection

To test that your Trivy filesystem scan is working correctly, you can create test files with known vulnerable dependencies:

### Test Files for Different Languages

#### Node.js Test
```json
// package.json
{
  "name": "test-vulnerable-app",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "4.17.15",
    "axios": "0.21.1",
    "moment": "2.29.1"
  }
}
```

#### Python Test
```txt
# requirements.txt
Flask==2.0.1
Django==3.2.0
requests==2.25.1
urllib3==1.26.5
```

#### Java Test
```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
    <version>2.14.1</version>
</dependency>
```

### Test Workflow
```yaml
name: Test Vulnerability Detection

on:
  workflow_dispatch:

jobs:
  test-scan:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Test Vulnerability Scan
        uses: Matrics-io/github-composites/trivy@main
        with:
          scan_type: "fs"
          scan_path: "."
          fail_on_cvss: "1.0"  # Lower threshold to see all vulnerabilities
          out_dir: "test-reports"
```

### Expected Results
With test files containing vulnerable dependencies, you should see:
- SARIF file with `results` array containing vulnerability details
- Specific CVE IDs and severity levels
- File paths where vulnerabilities were detected

## Troubleshooting

### Common Issues

1. **Timeout Errors**
   - Increase timeout: `timeout: "60"`
   - Use specific scan paths instead of entire repository

2. **High False Positive Rate**
   - Use `skip_dirs` to exclude irrelevant directories
   - Set `ignore_unfixed: "true"` for development environments
   - Adjust `severity` level to focus on important issues

3. **Image Not Found**
   - Ensure Docker image is built before scanning
   - Check image name and tag are correct
   - Verify Docker daemon is running

4. **Permission Issues**
   - Ensure `security-events: write` permission is set
   - Check repository secrets for private registries

5. **GitHub Security Tab Upload Fails**
   - Set `upload_sarif: "false"` if Code Security is not enabled in your repository
   - Check if your repository has GitHub Advanced Security enabled
   - Verify `security-events: write` permission is set in workflow

### Implementation Details

This action is a lightweight wrapper around the official [Aqua Security Trivy Action](https://github.com/aquasecurity/trivy-action) that:

- **Creates output directory** for reports
- **Maps inputs directly** to the official Trivy action
- **Uploads results** as artifacts and to GitHub Security tab
- **Provides consistent interface** across different scan types

The action leverages the official Trivy action's robust error handling, timeout management, and parameter validation, ensuring reliable and up-to-date vulnerability scanning.

### Performance Optimization

- **Use specific scan paths** instead of scanning entire repository
- **Skip irrelevant directories** with `skip_dirs`
- **Set appropriate timeouts** based on project size
- **Use `ignore_unfixed: "true"`** for faster development scans

## Requirements

- GitHub runner environment (configured via `DEFAULT_GITHUB_RUNNER` variable)
- Internet access for Trivy database updates
- Docker daemon (for image scanning)
- Sufficient disk space for vulnerability database

## Security Best Practices

1. **Set appropriate CVSS thresholds** based on your security requirements
2. **Scan both filesystem and images** in separate jobs for comprehensive coverage
3. **Review SARIF reports** regularly for security insights
4. **Integrate scanning into PR workflows** to catch issues early
5. **Use GitHub Security tab** for centralized vulnerability management
6. **Set up alerts** for high-severity vulnerabilities

1
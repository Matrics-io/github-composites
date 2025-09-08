# OWASP Dependency-Check Action

A streamlined GitHub composite action for running OWASP Dependency-Check vulnerability scanner with comprehensive reporting, BOM generation, and CVSS threshold enforcement.

## Features

- 🔍 **Comprehensive Vulnerability Scanning** - Scans dependencies for known CVEs
- 📊 **Multiple Report Formats** - XML, HTML, JSON, CSV, SARIF support
- 📋 **BOM Generation** - Automatic Bill of Materials creation
- 🛡️ **CVSS Threshold Enforcement** - Fail builds on high-severity vulnerabilities
- 🚀 **Robust Error Handling** - Multiple fallback strategies for reliability
- 📦 **Artifact Upload** - Automatic report artifact upload
- ⚡ **Fast Execution** - Minimal overhead, direct parameter mapping
- 🎯 **Flexible Configuration** - Customizable for various project needs

## Usage

### Basic Usage

```yaml
- name: OWASP Dependency-Check
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
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
  dependency-check:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Docker Login (if using private registry)
        uses: docker/login-action@v3
        with:
          registry: your-registry.com
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

             - name: Run OWASP Dependency-Check
         uses: Matrics-io/github-composites/owasp-dependency-check@main
        with:
          image: your-registry.com/owasp-dependency-check:latest
          scan_path: "."
          formats: "XML"
          out_dir: dependency-check-reports
          fail_on_cvss: "7.0"
          generate_bom: "true"
          timeout: "30"
          suppression_file: "dependency-check-suppressions.xml"
```

### Multiple Format Example

```yaml
- name: Run Dependency-Check with Multiple Formats
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
    formats: "XML"  # Primary format
    generate_bom: "true"  # Also generates BOM
    fail_on_cvss: "7.0"
```

### Minimal Example for Testing

```yaml
- name: Quick Dependency Scan
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
    fail_on_cvss: "10.0"  # Don't fail on vulnerabilities during testing
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `image` | Dependency-Check Docker image to use | Yes | `""` |
| `scan_path` | Path to scan for dependencies | No | `"."` |
| `out_dir` | Directory for generated reports | No | `"dependency-check-reports"` |
| `project_name` | Project name for reports | No | `"${{ github.repository }}@${{ github.sha }}"` |
| `formats` | Report formats (XML, HTML, JSON, CSV, SARIF) | No | `"XML"` |
| `fail_on_cvss` | Fail if CVSS score >= threshold (0.0-10.0) | No | `"7.0"` |
| `suppression_file` | Path to suppression XML file | No | `""` |
| `timeout` | Timeout in minutes | No | `"30"` |
| `generate_bom` | Generate Bill of Materials file | No | `"true"` |

## Outputs

The action generates the following artifacts that are automatically uploaded:

### Report Files
- **`dependency-check-report.xml`** - Main vulnerability report in XML format
- **`bom.xml`** - Bill of Materials file (if `generate_bom: true`)
- **Additional formats** - Based on `formats` input (HTML, JSON, etc.)

### Log Files
- **`dependency-check-*.log`** - Detailed execution logs for debugging

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

### Using Suppressions

Create a `dependency-check-suppressions.xml` file to suppress false positives:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
    <suppress>
        <notes>False positive - internal library</notes>
        <packageUrl regex="true">^pkg:npm/internal\-lib@.*$</packageUrl>
        <cve>CVE-2021-12345</cve>
    </suppress>
</suppressions>
```

Then reference it in your workflow:

```yaml
- name: Run Dependency-Check with Suppressions
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
    suppression_file: "dependency-check-suppressions.xml"
```

### Different Project Types

#### Node.js Projects
```yaml
- name: Install Dependencies
  run: npm ci

- name: Run Dependency-Check
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
    scan_path: "."
    formats: "XML"
```

#### Java Projects
```yaml
- name: Setup Java
  uses: actions/setup-java@v4
  with:
    java-version: '11'
    distribution: 'temurin'

- name: Build Project
  run: mvn compile

- name: Run Dependency-Check
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
    scan_path: "target"
```

#### Python Projects
```yaml
- name: Setup Python
  uses: actions/setup-python@v4
  with:
    python-version: '3.9'

- name: Install Dependencies
  run: pip install -r requirements.txt

- name: Run Dependency-Check
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
    scan_path: "."
```

### Multi-Directory Scanning
```yaml
- name: Scan Multiple Directories
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
    scan_path: "src,lib,vendor"
```

## Integration Examples

### Matrix Strategy for Multiple Projects

```yaml
strategy:
  matrix:
    project: [frontend, backend, mobile]
    
steps:
  - name: Checkout ${{ matrix.project }}
    uses: actions/checkout@v4
    with:
      path: ${{ matrix.project }}
      
  - name: Scan ${{ matrix.project }}
    uses: Matrics-io/github-composites/owasp-dependency-check@main
    with:
      image: your-registry/owasp-dependency-check:latest
      scan_path: "${{ matrix.project }}"
      out_dir: "reports-${{ matrix.project }}"
```

### Conditional Scanning

```yaml
- name: Check if dependencies exist
  id: deps-check
  run: |
    if [ -f "package.json" ] || [ -f "pom.xml" ] || [ -f "requirements.txt" ]; then
      echo "has-dependencies=true" >> $GITHUB_OUTPUT
    fi

- name: Run Dependency-Check
  if: steps.deps-check.outputs.has-dependencies == 'true'
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
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

- name: Run Dependency-Check
  uses: Matrics-io/github-composites/owasp-dependency-check@main
  with:
    image: your-registry/owasp-dependency-check:latest
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

  dependency-check:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    needs: test
    steps:
      - uses: actions/checkout@v4
      
      # Install dependencies for better analysis
      - name: Install Dependencies
        run: npm ci
      
      # Run dependency check
      - name: Dependency Vulnerability Scan
        uses: Matrics-io/github-composites/owasp-dependency-check@main
        with:
          image: your-registry/owasp-dependency-check:latest
          fail_on_cvss: "7.0"

  deploy:
    runs-on: ${{ vars.DEFAULT_GITHUB_RUNNER }}
    needs: [test, dependency-check]
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to Production
        run: echo "Deploying..."
```

## Troubleshooting

### Common Issues

1. **Out of Memory Errors**
   - Increase timeout: `timeout: "60"`
   - The action includes automatic memory optimization

2. **No Dependencies Found**
   - Ensure `package.json`, `pom.xml`, or other dependency files exist
   - Install dependencies before scanning (e.g., `npm install`)

3. **False Positives**
   - Use suppression files to exclude known false positives
   - Set higher CVSS threshold temporarily: `fail_on_cvss: "8.0"`

4. **Timeout Issues**
   - Increase timeout for large projects: `timeout: "45"`
   - Consider scanning specific directories only

### Debug Mode

For troubleshooting, the action provides comprehensive logging. Check the uploaded artifacts for:
- `dependency-check-*.log` - Detailed execution logs
- `dependency-check-*-output.log` - Command output logs

### Performance Optimization

- **Install dependencies first** for better analysis
- **Use specific scan paths** instead of scanning entire repository
- **Set appropriate timeouts** based on project size
- **Use suppression files** to reduce false positives

## Requirements

- GitHub runner environment (configured via `DEFAULT_GITHUB_RUNNER` variable)
- Docker must be available in the runner environment
- Access to the specified Docker image registry
- Sufficient disk space for report generation
- Internet access for vulnerability database updates (when using `--update`)

## Security Best Practices

1. **Set appropriate CVSS thresholds** based on your security requirements
2. **Use suppression files** to handle false positives 
3. **Review generated reports** regularly for security insights
4. **Integrate scanning into PR workflows** to catch issues early
5. **Store scan results as artifacts** for compliance and audit purposes
6. **Install dependencies before scanning** for comprehensive analysis

## Implementation Details

This action is a robust wrapper around OWASP Dependency-Check that:

- **Creates output directory** for reports
- **Runs comprehensive vulnerability scanning** with multiple fallback strategies
- **Generates BOM files** for supply chain visibility
- **Uploads results** as artifacts for audit trails
- **Provides detailed logging** for troubleshooting

The action includes advanced error handling and fallback mechanisms to ensure reliable execution across different project types and environments. 1
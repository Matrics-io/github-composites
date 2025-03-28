## Overview
Welcome to **91Life GitHub Composites**! This repository is a collection of **reusable GitHub Actions workflows** and **composite actions** designed to automate and optimize your development processes. With these actions, you can streamline tasks like **CI/CD pipelines**, **testing**, **building**, **deploying**, and **integration** with third-party services, all within your GitHub repository.

Each action is modular and reusable, making it easy to integrate into any of your GitHub repositories. You can use these actions independently or combine them to create sophisticated workflows for a seamless automation experience.

### Key Features:
- **Modular Actions**: Each GitHub Action is a self-contained module that can be reused across different repositories.
- **Automation**: Automate repetitive tasks like building, testing, deployment, and more.
- **Consistency**: Standardize your development processes and workflows across multiple projects.
- **Easy Integration**: Plug these actions directly into your GitHub workflows with minimal setup.

---

### Example Usage

Here’s how you can use any action from this repository within your GitHub workflows.

#### 1. Add the Action to Your Workflow  
To integrate a specific action, reference the action using the format `91Life/[action name]@main` (or any specific tag or branch).

For example, if you want to use the action named `build-and-deploy`, you would add the following to your `.github/workflows/ci.yml` (or any workflow file) in your repository:

```yaml
name: CI Pipeline

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      # Checkout the repository
      - name: Checkout code
        uses: actions/checkout@v2

      # Use the reusable GitHub Action from this repository
      - name: Build and Deploy
        uses: 91Life/build-and-deploy@main  # or specify a tag like v1.0.0
        with:
          param1: value1
          param2: value2

      # Example of additional steps
      - name: Run Tests
        run: npm test
```

#### 2. Customize Parameters  
Each action can accept specific parameters. For example, the `build-and-deploy` action might require environment-specific variables or API keys. You can pass these parameters under the `with` section in your workflow YAML.

#### 3. Use Specific Tags or Branches  
If you want to pin the action to a specific version or branch, you can replace `@main` with a tag or branch name. For example:

```yaml
uses: 91Life/build-and-deploy@v1.0.0 # Using a specific tag
```
or
```yaml
uses: 91Life/build-and-deploy@feature-branch # Using a custom branch
```

#### 4. Set Up Secrets and Environment Variables  
If the action requires secrets (such as API tokens, cloud credentials, etc.), make sure to set them in your repository’s settings under **Settings** > **Secrets**. Reference these secrets in the action as needed.

---

### Why Use These Actions?
- **Streamline your CI/CD**: Automate every step of your development pipeline, from testing to deployment.
- **Save time**: Reuse well-tested and pre-built actions to eliminate the need to create custom scripts.
- **Consistency**: Ensure your pipelines run the same way across multiple repositories, teams, and projects.

For more details on each specific action, refer to the individual action’s documentation or repository. This allows you to easily integrate and extend your workflows with minimal configuration.

Feel free to explore and start automating your workflows with **91Life GitHub Composites** today!

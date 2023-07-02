#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Enable tracing if the BASH_TRACE environment variable is set to 1
if [[ "${BASH_TRACE:-0}" == "1" ]]; then
    set -o xtrace
fi

# Check if the GITHUB_PERSONAL_ACCESS_TOKEN environment variable is set
if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "GITHUB_PERSONAL_ACCESS_TOKEN environment variable is missing"
    exit 1
fi

# Change the working directory to the script's directory
cd "$(dirname "$0")"

# Check if four arguments are provided, otherwise exit with an error message
if [ "$#" -eq 4 ]; then
    echo > /dev/null
else
    echo "The script was not provided with four arguments."
    echo "Usage: ./mid-term.sh CODE_REPO_URL CODE_BRANCH_NAME REPORT_REPO_URL REPORT_BRANCH_NAME"
    exit 1
fi

# Assign the arguments to variables
CODE_REPO_URL="$1"
CODE_BRANCH_NAME="$2"
REPORT_REPO_URL="$3"
REPORT_BRANCH_NAME="$4"

# Extract the repository names and owner from the repository URLs
CODE_REPOSITORY_NAME=$(basename "$CODE_REPO_URL" .git)
REPOSITORY_OWNER=$(basename "$(dirname "$CODE_REPO_URL")")
REPORT_REPOSITORY_NAME=$(basename "$REPORT_REPO_URL" .git)

# Create temporary directories for code and report repositories
CODE_REPOSITORY_PATH=$(mktemp --directory)
REPORT_REPOSITORY_PATH=$(mktemp --directory)

# Set initial values for test results
PYTEST_RESULT=0
BLACK_RESULT=0

# Check if the code repository exists and the specified branch exists
if git ls-remote --exit-code "$CODE_REPO_URL" &> /dev/null; then
    if git ls-remote --exit-code --heads "$CODE_REPO_URL" "$CODE_BRANCH_NAME" &> /dev/null; then
        echo > /dev/null
    else
        echo "Branch '$CODE_BRANCH_NAME' does not exist"
        exit 1
    fi
else
    echo "Repository does not exist"
    exit 1
fi

# Check if the report repository exists and the specified branch exists
if git ls-remote --exit-code "$REPORT_REPO_URL" &> /dev/null; then
    echo > /dev/null
    if git ls-remote --exit-code --heads "$REPORT_REPO_URL" "$REPORT_BRANCH_NAME" &> /dev/null; then
        echo > /dev/null
    else
        echo "Branch '$REPORT_BRANCH_NAME' does not exist"
        exit 1
    fi
else
    echo "Repository does not exist"
    exit 1
fi

# Check if pytest and black commands are available
if ! pytest --version >/dev/null 2>&1; then
    echo "pytest is not installed"
    exit 1
fi

if ! black --version >/dev/null 2>&1; then
    echo "black is not installed"
    exit 1
fi

# Function to perform cleanup actions
cleanup() {
    echo "Cleaning up..."
    if [ -d "$CODE_REPOSITORY_PATH" ]; then
        rm -rf "$CODE_REPOSITORY_PATH"
        echo "Deleted CODE_REPOSITORY_PATH"
    fi
    if [ -d "$REPORT_REPOSITORY_PATH" ]; then
        rm -rf "$REPORT_REPOSITORY_PATH"
        echo "Deleted REPORT_REPOSITORY_PATH"
    fi
    if [ -f "$PYTEST_REPORT_PATH" ]; then
        rm -rf "$PY.

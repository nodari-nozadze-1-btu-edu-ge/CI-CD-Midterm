#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Enable tracing if BASH_TRACE is set to 1
if [[ "${BASH_TRACE:-0}" == "1" ]]; then
    set -o xtrace
fi

# Check if GITHUB_PERSONAL_ACCESS_TOKEN environment variable is set
if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "GITHUB_PERSONAL_ACCESS_TOKEN environment variable is missing"
    exit 1
fi

# Change to the directory of the script
cd "$(dirname "$0")"

# Check if the script was provided with four arguments
if [ "$#" -ne 4 ]; then
    echo "The script was not provided with four arguments."
    echo "Usage: ./mid-term.sh CODE_REPO_URL CODE_BRANCH_NAME REPORT_REPO_URL REPORT_BRANCH_NAME"
    exit 1
fi

# Assign argument values to variables
CODE_REPO_URL="$1"
CODE_BRANCH_NAME="$2"
REPORT_REPO_URL="$3"
REPORT_BRANCH_NAME="$4"

# Extract repository name and owner from the code repository URL
REPOSITORY_NAME_CODE=$(basename "$CODE_REPO_URL" .git)
REPOSITORY_OWNER=$(basename "$(dirname "$CODE_REPO_URL")")

# Extract repository name from the report repository URL
REPOSITORY_NAME_REPORT=$(basename "$REPORT_REPO_URL" .git)

# Create temporary directories for code and report repositories
REPOSITORY_PATH_CODE=$(mktemp --directory)
REPOSITORY_PATH_REPORT=$(mktemp --directory)

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

# Check if pytest and black are installed
if ! pytest --version >/dev/null 2>&1; then
    echo "pytest is not installed"
    exit 1
fi

if ! black --version >/dev/null 2>&1; then
    echo "black is not installed"
    exit 1
fi

# Function to clean up temporary files and directories
cleanup() {
    echo "Cleaning up..."
    if [ -d "$REPOSITORY_PATH_CODE" ]; then
        rm -rf "$REPOSITORY_PATH_CODE"
        echo "Deleted REPOSITORY_PATH_CODE"
    fi
    if [ -d "$REPOSITORY_PATH_REPORT" ]; then
        rm -rf "$REPOSITORY_PATH_REPORT"
        echo "Deleted REPOSITORY_PATH_REPORT"
    fi
    if [ -f "$PYTEST_REPORT_PATH" ]; then
        rm -rf "$PYTEST_REPORT_PATH"
        echo "Deleted PYTEST_REPORT_PATH"
    fi
    if [ -f "$BLACK_REPORT_PATH" ]; then
        rm -rf "$BLACK_REPORT_PATH"
        echo "Deleted BLACK_REPORT_PATH"
    fi
    if [ -f "$BLACK_OUTPUT_PATH" ]; then
        rm -rf "$BLACK_OUTPUT_PATH"
        echo "Deleted BLACK_OUTPUT_PATH"
    fi   
}

# Trap signals to perform cleanup on script termination
trap cleanup INT EXIT ERR SIGINT SIGTERM

# Function to make a GET request to GitHub API
github_api_get_request() {
    curl --request GET \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        --output "$2" \
        --silent \
        "$1"
}

# Function to make a POST request to GitHub API
github_post_request() {
    curl --request POST \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        --header "Content-Type: application/json" \
        --silent \
        --output "$3" \
        --data-binary "@$2" \
        "$1"
}

# Function to update a JSON file using jq
jq_update() {
    local IO_PATH=$1
    local TEMP_PATH=$(mktemp)
    shift
    cat "$IO_PATH" | jq "$@" > "$TEMP_PATH"
    mv "$TEMP_PATH" "$IO_PATH"
}

# Clone the code repository to the code directory
git clone "$CODE_REPO_URL" "$REPOSITORY_PATH_CODE"
cd "$REPOSITORY_PATH_CODE"
git switch "$CODE_BRANCH_NAME"

# Get the last commit hash
LAST_COMMIT="$(git log -n 1 --format=%H)"

while true; do
    # Fetch changes from the code repository
    git fetch "$1" "$2" > /dev/null 2>&1
    CHECK_COMMIT=$(git rev-parse FETCH_HEAD)

    # Check if there are new commits
    if [ "$CHECK_COMMIT" != "$LAST_COMMIT" ]; then
        # Get the list of commits between the last commit and the new commit
        COMMITS=$(git log --pretty=format:"%H" --reverse "$LAST_COMMIT..$CHECK_COMMIT")
        echo "$COMMITS"
        LAST_COMMIT=$CHECK_COMMIT

        for COMMIT in $COMMITS; do
            PYTEST_REPORT_PATH=$(mktemp)
            BLACK_OUTPUT_PATH=$(mktemp)
            BLACK_REPORT_PATH=$(mktemp)

            # Checkout the commit
            git checkout "$COMMIT"

            # Get the author's email
            AUTHOR_EMAIL=$(git log -n 1 --format="%ae" HEAD)

            # Run pytest and save the report
            if pytest --verbose --html="$PYTEST_REPORT_PATH" --self-contained-html; then
                PYTEST_RESULT=$?
                echo "PYTEST SUCCEEDED $PYTEST_RESULT"
            else
                PYTEST_RESULT=$?
                echo "PYTEST FAILED $PYTEST_RESULT"
            fi

            echo "\$PYTEST_RESULT = $PYTEST_RESULT \$BLACK_RESULT=$BLACK_RESULT"

            # Run black and check code formatting
            if black --check --diff *.py > "$BLACK_OUTPUT_PATH"; then
                BLACK_RESULT=$?
                echo "BLACK SUCCEEDED $BLACK_RESULT"
            else
                BLACK_RESULT=$?
                echo "BLACK FAILED $BLACK_RESULT"
                cat "$BLACK_OUTPUT_PATH" | pygmentize -l diff -f html -O full,style=solarized-light -o "$BLACK_REPORT_PATH"
            fi

            echo "\$PYTEST_RESULT = $PYTEST_RESULT \$BLACK_RESULT=$BLACK_RESULT"

            # Check if the report repository has already been cloned
            if [ -d "$REPOSITORY_PATH_REPORT" ] && [ "$(ls -A "$REPOSITORY_PATH_REPORT")" ]; then
                echo "Directory $REPOSITORY_PATH_REPORT exists and is not empty. Skipping cloning."
            else
                git clone "$REPORT_REPO_URL" "$REPOSITORY_PATH_REPORT"
            fi

            pushd "$REPOSITORY_PATH_REPORT"
            git switch "$REPORT_BRANCH_NAME"

            # Create a directory for the report
            REPORT_PATH="${COMMIT}-$(date +%s)"
            mkdir --parents "$REPORT_PATH"
            cp "$PYTEST_REPORT_PATH" "$REPORT_PATH/pytest.html"

            # Copy the black report if it exists
            if [ -s "$BLACK_REPORT_PATH" ]; then
                cp "$BLACK_REPORT_PATH" "$REPORT_PATH/black.html"
            fi

            git add "$REPORT_PATH"
            git commit -m "$COMMIT report."
            git push
            popd

            # Check the test and formatting results
            if (( ($PYTEST_RESULT != 0) || ($BLACK_RESULT != 0) )); then
                AUTHOR_USERNAME=""
                RESPONSE_PATH=$(mktemp)
                github_api_get_request "https://api.github.com/search/users?q=$AUTHOR_EMAIL" "$RESPONSE_PATH"

                TOTAL_USER_COUNT=$(cat "$RESPONSE_PATH" | jq ".total_count")

                if [[ $TOTAL_USER_COUNT == 1 ]]; then
                    USER_JSON=$(cat "$RESPONSE_PATH" | jq ".items[0]")
                    AUTHOR_USERNAME=$(cat "$RESPONSE_PATH" | jq --raw-output ".items[0].login")
                fi

                REQUEST_PATH=$(mktemp)
                RESPONSE_PATH=$(mktemp)
                echo "{}" > "$REQUEST_PATH"

                BODY+="Automatically generated message\n\n"

                if (( $PYTEST_RESULT != 0 )); then
                    if (( $BLACK_RESULT != 0 )); then
                        if [[ "$PYTEST_RESULT" -eq "5" ]]; then
                            TITLE="${COMMIT::7} Unit tests do not exist in the repository or do not work correctly and formatting test failed."
                            BODY+="${COMMIT} Unit tests do not exist in the repository or do not work correctly and formatting test failed.\n"
                        else
                            TITLE="${COMMIT::7} failed unit and formatting tests."
                            BODY+="${COMMIT} failed unit and formatting tests.\n"
                            jq_update "$REQUEST_PATH" '.labels = ["ci-pytest", "ci-black"]'
                        fi
                    else
                        if [[ "$PYTEST_RESULT" -eq "5" ]]; then
                            TITLE="${COMMIT::7} Unit tests do not exist in the repository or do not work correctly and formatting test passed."
                            BODY+="${COMMIT} Unit tests do not exist in the repository or do not work correctly and formatting test passed.\n"
                        else
                            TITLE="${COMMIT::7} failed unit tests."
                            BODY+="${COMMIT} failed unit tests.\n"
                            jq_update "$REQUEST_PATH" '.labels = ["ci-pytest"]'
                        fi
                    fi
                else
                    TITLE="${COMMIT::7} failed formatting test."
                    BODY+="${COMMIT} failed formatting test.\n"
                    jq_update "$REQUEST_PATH" '.labels = ["ci-black"]'
                fi

                BODY+="Pytest report: https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME_REPORT}/$REPORT_PATH/pytest.html\n"
                BODY+="Black report: https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME_REPORT}/$REPORT_PATH/black.html\n"

                jq_update "$REQUEST_PATH" '.title = "'"$TITLE"'"'
                jq_update "$REQUEST_PATH" '.body = "'"$BODY"'"'

                # Create an issue on the code repository
                github_post_request "https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME_CODE}/issues" "$REQUEST_PATH" "$RESPONSE_PATH"

                ISSUE_NUMBER=$(cat "$RESPONSE_PATH" | jq --raw-output ".number")

                # Create a comment on the report repository
                COMMENT_BODY="Failed tests: https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME_REPORT}/$REPORT_PATH/pytest.html"

                if [[ -n "$AUTHOR_USERNAME" ]]; then
                    COMMENT_BODY+="\n\n@${AUTHOR_USERNAME}"
                fi

                github_post_request "https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME_REPORT}/issues/${ISSUE_NUMBER}/comments" <(echo "{\"body\":\"${COMMENT_BODY}\"}") "$RESPONSE_PATH"
            fi
        done
    fi

    sleep 30
done

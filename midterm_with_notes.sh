#!/bin/bash
#This is called a shebang or hashbang. It tells the system that this script should be executed using the bash interpreter. 
set -o errexit #Exit immediately if a command exits with a non-zero status.
set -o nounset #Treat unset variables as an error when substituting.
set -o pipefail #Return the exit code of the last command in the pipe that failed.

# Enable tracing if BASH_TRACE is set to 1
if [[ "${BASH_TRACE:-0}" == "1" ]]; then #If the variable BASH_TRACE is set to 1, then enable tracing.
    set -o xtrace #causes the script to print each command before it is executed. Useful for debugging.
fi

# Check if GITHUB_PERSONAL_ACCESS_TOKEN environment variable is set
if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then #If the variable GITHUB_PERSONAL_ACCESS_TOKEN is not set, then exit with an error.
    echo "GITHUB_PERSONAL_ACCESS_TOKEN environment variable is missing" #Print the message to the standard output.
    exit 1 #Exit with an error.
fi

# Change to the directory of the script
cd "$(dirname "$0")"

# Check if the script was provided with four arguments
if [ "$#" -ne 4 ]; then #This line checks if the script was provided with four command-line arguments. The variable $# holds the number of arguments passed to the script
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
REPOSITORY_NAME_CODE=$(basename "$CODE_REPO_URL" .git) #The basename command strips the .git extension from the URL.
REPOSITORY_OWNER=$(basename "$(dirname "$CODE_REPO_URL")") #In this case, it strips the repository name from the URL.

# Extract repository name from the report repository URL
REPOSITORY_NAME_REPORT=$(basename "$REPORT_REPO_URL" .git)

# Create temporary directories for code and report repositories
REPOSITORY_PATH_CODE=$(mktemp --directory)
REPOSITORY_PATH_REPORT=$(mktemp --directory)

PYTEST_RESULT=0 #This variable will hold the result of the pytest command. If the command succeeds, then the variable will be set to 0. Otherwise, it will be set to 1.
BLACK_RESULT=0 #This variable will hold the result of the black command. If the command succeeds, then the variable will be set to 0. Otherwise, it will be set to 1.

# Check if the code repository exists and the specified branch exists
if git ls-remote --exit-code "$CODE_REPO_URL" &> /dev/null; then #The git ls-remote command checks if the repository exists. If it does, then the command returns 0. Otherwise, it returns 1.
    if git ls-remote --exit-code --heads "$CODE_REPO_URL" "$CODE_BRANCH_NAME" &> /dev/null; then #The git ls-remote command checks if the branch exists. If it does, then the command returns 0. Otherwise, it returns 1.
        echo > /dev/null #This line is used to suppress the output of the command.
    else
        echo "Branch '$CODE_BRANCH_NAME' does not exist" #If the branch does not exist, then print an error message and exit with an error.
        exit 1 #Exit with an error.
    fi
else
    echo "Repository does not exist" #If the repository does not exist, then print an error message and exit with an error.
    exit 1 #Exit with an error.
fi

# Check if the report repository exists and the specified branch exists
if git ls-remote --exit-code "$REPORT_REPO_URL" &> /dev/null; then #The git ls-remote command checks if the repository exists. If it does, then the command returns 0. Otherwise, it returns 1.
    echo > /dev/null #This line is used to suppress the output of the command.
    if git ls-remote --exit-code --heads "$REPORT_REPO_URL" "$REPORT_BRANCH_NAME" &> /dev/null; then #The git ls-remote command checks if the branch exists. If it does, then the command returns 0. Otherwise, it returns 1.
        echo > /dev/null #This line is used to suppress the output of the command.
    else
        echo "Branch '$REPORT_BRANCH_NAME' does not exist" #If the branch does not exist, then print an error message and exit with an error.
        exit 1 #Exit with an error.
    fi
else
    echo "Repository does not exist" #If the repository does not exist, then print an error message and exit with an error.
    exit 1 #Exit with an error.
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
cleanup() { #This function will be called when the script exits.
    echo "Cleaning up..." #Print a message to the standard output.
    if [ -d "$REPOSITORY_PATH_CODE" ]; then  #Check if the directory exists.
        rm -rf "$REPOSITORY_PATH_CODE" #If it does, then remove it.
        echo "Deleted REPOSITORY_PATH_CODE" #Print a message to the standard output.
    fi
    if [ -d "$REPOSITORY_PATH_REPORT" ]; then #Check if the directory exists.
        rm -rf "$REPOSITORY_PATH_REPORT" #If it does, then remove it.
        echo "Deleted REPOSITORY_PATH_REPORT" #Print a message to the standard output.
    fi
    if [ -f "$PYTEST_REPORT_PATH" ]; then #Check if the file exists.
        rm -rf "$PYTEST_REPORT_PATH" #If it does, then remove it.
        echo "Deleted PYTEST_REPORT_PATH" #Print a message to the standard output.
    fi
    if [ -f "$BLACK_REPORT_PATH" ]; then #Check if the file exists.
        rm -rf "$BLACK_REPORT_PATH" #If it does, then remove it.
        echo "Deleted BLACK_REPORT_PATH" #Print a message to the standard output.
    fi
    if [ -f "$BLACK_OUTPUT_PATH" ]; then   #Check if the file exists.
        rm -rf "$BLACK_OUTPUT_PATH" #If it does, then remove it.
        echo "Deleted BLACK_OUTPUT_PATH" #Print a message to the standard output.
    fi   
}

# Trap signals to perform cleanup on script termination
trap cleanup INT EXIT ERR SIGINT SIGTERM #The trap command is used to trap signals and execute a command when the signal is received. In this case, the cleanup function is executed when the script exits.

# Function to make a GET request to GitHub API
github_api_get_request() {  #This function takes two arguments: the URL and the output file path.
    curl --request GET \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        --output "$2" \
        --silent \
        "$1"
}

# Function to make a POST request to GitHub API
github_post_request() { #This function takes three arguments: the URL, the input file path, and the output file path.
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
jq_update() { #This function takes at least two arguments: the input file path and the jq command.
    local IO_PATH=$1 #The input file path is stored in the IO_PATH variable.
    local TEMP_PATH=$(mktemp) #A temporary file path is created and stored in the TEMP_PATH variable.
    shift #The first argument is removed from the argument list.
    cat "$IO_PATH" | jq "$@" > "$TEMP_PATH" #The jq command is executed on the input file and the output is stored in the temporary file.
    mv "$TEMP_PATH" "$IO_PATH" #The temporary file is moved to the input file path.
}

# Clone the code repository to the code directory
git clone "$CODE_REPO_URL" "$REPOSITORY_PATH_CODE" #The git clone command is used to clone the code repository to the code directory.
cd "$REPOSITORY_PATH_CODE" #The current working directory is changed to the code directory.
git switch "$CODE_BRANCH_NAME" #The git switch command is used to switch to the code branch.

# Get the last commit hash
LAST_COMMIT="$(git log -n 1 --format=%H)"   #The git log command is used to get the last commit hash.

while true; do
    # Fetch changes from the code repository
    git fetch "$1" "$2" > /dev/null 2>&1 #The git fetch command is used to fetch changes from the code repository.
    CHECK_COMMIT=$(git rev-parse FETCH_HEAD) #The git rev-parse command is used to get the commit hash of the latest commit.

    # Check if there are new commits
    if [ "$CHECK_COMMIT" != "$LAST_COMMIT" ]; then #If there are new commits, then the script will continue.
        # Get the list of commits between the last commit and the new commit
        COMMITS=$(git log --pretty=format:"%H" --reverse "$LAST_COMMIT..$CHECK_COMMIT") #The git log command is used to get the list of commits between the last commit and the new commit.
        echo "$COMMITS" #The list of commits is printed to the standard output.
        LAST_COMMIT=$CHECK_COMMIT #The last commit is updated.

        for COMMIT in $COMMITS; do #The script will iterate through the list of commits.
            PYTEST_REPORT_PATH=$(mktemp) #A temporary file path is created and stored in the PYTEST_REPORT_PATH variable.
            BLACK_OUTPUT_PATH=$(mktemp) #A temporary file path is created and stored in the BLACK_OUTPUT_PATH variable.
            BLACK_REPORT_PATH=$(mktemp) #A temporary file path is created and stored in the BLACK_REPORT_PATH variable.

            # Checkout the commit
            git checkout "$COMMIT"

            # Get the author's email
            AUTHOR_EMAIL=$(git log -n 1 --format="%ae" HEAD) #The git log command is used to get the author's email.

            # Run pytest and save the report
            if pytest --verbose --html="$PYTEST_REPORT_PATH" --self-contained-html; then #The pytest command is used to run the tests and save the report.
                PYTEST_RESULT=$? #The exit code of the pytest command is stored in the PYTEST_RESULT variable.
                echo "PYTEST SUCCEEDED $PYTEST_RESULT" #A message is printed to the standard output.
            else
                PYTEST_RESULT=$? #The exit code of the pytest command is stored in the PYTEST_RESULT variable.
                echo "PYTEST FAILED $PYTEST_RESULT" #A message is printed to the standard output.
            fi
            # Check if the report repository has already been cloned
            echo "\$PYTEST_RESULT = $PYTEST_RESULT \$BLACK_RESULT=$BLACK_RESULT" #A message is printed to the standard output.

            # Run black and check code formatting
            if black --check --diff *.py > "$BLACK_OUTPUT_PATH"; then #The black command is used to check the code formatting.
                BLACK_RESULT=$? #The exit code of the black command is stored in the BLACK_RESULT variable.
                echo "BLACK SUCCEEDED $BLACK_RESULT" #A message is printed to the standard output.
            else
                BLACK_RESULT=$? #The exit code of the black command is stored in the BLACK_RESULT variable.
                echo "BLACK FAILED $BLACK_RESULT" #A message is printed to the standard output.
                #The pygmentize command is used to highlight the differences between the code and the black output.
                cat "$BLACK_OUTPUT_PATH" | pygmentize -l diff -f html -O full,style=solarized-light -o "$BLACK_REPORT_PATH"
            fi

            echo "\$PYTEST_RESULT = $PYTEST_RESULT \$BLACK_RESULT=$BLACK_RESULT" #A message is printed to the standard output.

            # Check if the report repository has already been cloned
            if [ -d "$REPOSITORY_PATH_REPORT" ] && [ "$(ls -A "$REPOSITORY_PATH_REPORT")" ]; then #If the report repository has already been cloned, then the script will continue.
                echo "Directory $REPOSITORY_PATH_REPORT exists and is not empty. Skipping cloning." #A message is printed to the standard output.
            else
                git clone "$REPORT_REPO_URL" "$REPOSITORY_PATH_REPORT" #The git clone command is used to clone the report repository to the report directory.
            fi

            pushd "$REPOSITORY_PATH_REPORT" #The current working directory is changed to the report directory.
            git switch "$REPORT_BRANCH_NAME" #The git switch command is used to switch to the report branch.

            # Create a directory for the report
            REPORT_PATH="${COMMIT}-$(date +%s)"
            mkdir --parents "$REPORT_PATH"
            cp "$PYTEST_REPORT_PATH" "$REPORT_PATH/pytest.html"

            # Copy the black report if it exists
            if [ -s "$BLACK_REPORT_PATH" ]; then #If the black report exists, then the script will continue.
                cp "$BLACK_REPORT_PATH" "$REPORT_PATH/black.html" #The black report is copied to the report directory.
            fi

            git add "$REPORT_PATH" #The git add command is used to add the report directory to the git index.
            git commit -m "$COMMIT report." #The git commit command is used to commit the changes to the report directory.
            git push #The git push command is used to push the changes to the report repository.
            popd #The current working directory is changed to the previous directory.

            # Check the test and formatting results
            if (( ($PYTEST_RESULT != 0) || ($BLACK_RESULT != 0) )); then #If the test or formatting results are not successful, then the script will continue.
                AUTHOR_USERNAME=""
                RESPONSE_PATH=$(mktemp)
                github_api_get_request "https://api.github.com/search/users?q=$AUTHOR_EMAIL" "$RESPONSE_PATH" #The github_api_get_request function is used to get the author's username.

                TOTAL_USER_COUNT=$(cat "$RESPONSE_PATH" | jq ".total_count") #The total user count is stored in the TOTAL_USER_COUNT variable.

                if [[ $TOTAL_USER_COUNT == 1 ]]; then   #If the total user count is 1, then the script will continue.
                    USER_JSON=$(cat "$RESPONSE_PATH" | jq ".items[0]") #The user JSON is stored in the USER_JSON variable.
                    AUTHOR_USERNAME=$(cat "$RESPONSE_PATH" | jq --raw-output ".items[0].login") #The author's username is stored in the AUTHOR_USERNAME variable.
                fi

                REQUEST_PATH=$(mktemp) #A temporary file path is created and stored in the REQUEST_PATH variable.
                RESPONSE_PATH=$(mktemp) #A temporary file path is created and stored in the RESPONSE_PATH variable.
                echo "{}" > "$REQUEST_PATH" #An empty JSON object is written to the REQUEST_PATH file.

                BODY+="Automatically generated message\n\n" #A message is added to the BODY variable.

                if (( $PYTEST_RESULT != 0 )); then #If the pytest result is not successful, then the script will continue.
                    if (( $BLACK_RESULT != 0 )); then #If the black result is not successful, then the script will continue.
                        if [[ "$PYTEST_RESULT" -eq "5" ]]; then #If the pytest result is 5, then the script will continue.
                            TITLE="${COMMIT::7} Unit tests do not exist in the repository or do not work correctly and formatting test failed." #A message is stored in the TITLE variable.
                            BODY+="${COMMIT} Unit tests do not exist in the repository or do not work correctly and formatting test failed.\n" #A message is added to the BODY variable.
                        else
                            TITLE="${COMMIT::7} failed unit and formatting tests." #A message is stored in the TITLE variable.
                            BODY+="${COMMIT} failed unit and formatting tests.\n" #A message is added to the BODY variable.
                            jq_update "$REQUEST_PATH" '.labels = ["ci-pytest", "ci-black"]' #The jq_update function is used to update the labels of the request.
                        fi
                    else
                        if [[ "$PYTEST_RESULT" -eq "5" ]]; then #If the pytest result is 5, then the script will continue.
                            TITLE="${COMMIT::7} Unit tests do not exist in the repository or do not work correctly and formatting test passed."     #A message is stored in the TITLE variable.
                            BODY+="${COMMIT} Unit tests do not exist in the repository or do not work correctly and formatting test passed.\n"   #A message is added to the BODY variable.
                        else
                            TITLE="${COMMIT::7} failed unit tests." #A message is stored in the TITLE variable.
                            BODY+="${COMMIT} failed unit tests.\n" #A message is added to the BODY variable.
                            jq_update "$REQUEST_PATH" '.labels = ["ci-pytest"]' #The jq_update function is used to update the labels of the request.
                        fi
                    fi
                else
                    TITLE="${COMMIT::7} failed formatting test." #A message is stored in the TITLE variable.
                    BODY+="${COMMIT} failed formatting test.\n" #A message is added to the BODY variable.
                    jq_update "$REQUEST_PATH" '.labels = ["ci-black"]' #The jq_update function is used to update the labels of the request.
                fi

                BODY+="Pytest report: https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME_REPORT}/$REPORT_PATH/pytest.html\n" #A message is added to the BODY variable.
                BODY+="Black report: https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME_REPORT}/$REPORT_PATH/black.html\n" #A message is added to the BODY variable.

                jq_update "$REQUEST_PATH" '.title = "'"$TITLE"'"' #The jq_update function is used to update the title of the request.
                jq_update "$REQUEST_PATH" '.body = "'"$BODY"'"' #The jq_update function is used to update the body of the request.

                # Create an issue on the code repository
                github_post_request "https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME_CODE}/issues" "$REQUEST_PATH" "$RESPONSE_PATH" #The github_post_request function is used to create an issue on the code repository.

                ISSUE_NUMBER=$(cat "$RESPONSE_PATH" | jq --raw-output ".number") #The issue number is stored in the ISSUE_NUMBER variable.

                # Create a comment on the report repository
                COMMENT_BODY="Failed tests: https://${REPOSITORY_OWNER}.github.io/${REPOSITORY_NAME_REPORT}/$REPORT_PATH/pytest.html" #A message is stored in the COMMENT_BODY variable.

                if [[ -n "$AUTHOR_USERNAME" ]]; then #If the author's username is not empty, then the script will continue.
                    COMMENT_BODY+="\n\n@${AUTHOR_USERNAME}" #A message is added to the COMMENT_BODY variable.
                fi

                github_post_request "https://api.github.com/repos/${REPOSITORY_OWNER}/${REPOSITORY_NAME_REPORT}/issues/${ISSUE_NUMBER}/comments" <(echo "{\"body\":\"${COMMENT_BODY}\"}") "$RESPONSE_PATH" #The github_post_request function is used to create a comment on the report repository.
            fi
        done #The for loop is closed.
    fi

    sleep 30 #The script will sleep for 30 seconds.
done #The while loop is closed.

Midterm.sh
midterm.sh is a bash script designed to automate the testing and reporting of code repositories hosted on GitHub. It performs unit tests using Pytest and checks code formatting using Black. It generates reports and notifies the repository owner about any test failures or formatting issues via GitHub issues.

Prerequisites
Before using midterm.sh, ensure that the following requirements are met:

Bash Shell: The script requires a Bash shell to run. Make sure that Bash is installed on your system.

Git: Git is required for cloning repositories and fetching the latest commits. Install Git on your system if it is not already installed.

Python and Pytest: Pytest is used to perform unit tests on the code. Ensure that Python and Pytest are installed on your system.

GitHub API Token: Obtain a personal access token from GitHub that has the necessary permissions to create issues on repositories. Keep the token securely as it grants access to your GitHub account.

JQ: JQ is a command-line JSON processor used in the script to process JSON data. Install JQ on your system using the appropriate package manager.

Usage
Follow the steps below to use midterm.sh:

Clone the Repository: Clone the repository containing the midterm.sh script to your local machine.

Set the GitHub API Token: Open the midterm.sh script in a text editor. Locate the GITHUB_PERSONAL_ACCESS_TOKEN variable and replace YOUR_TOKEN_HERE with your actual GitHub API Token.

Make the Script Executable: Make the midterm.sh script executable by running the following command in the terminal:

bash
Copy code
chmod +x midterm.sh
Execute the Script: Run the script using the following command:

bash
Copy code
./midterm.sh CODE_REPO_URL CODE_BRANCH_NAME REPORT_REPO_URL REPORT_BRANCH_NAME
Replace CODE_REPO_URL with the URL of the code repository you want to test. Replace CODE_BRANCH_NAME with the name of the branch to test. Replace REPORT_REPO_URL with the URL of the repository where the reports will be stored. Replace REPORT_BRANCH_NAME with the name of the branch in the report repository.

Monitor the Output: The script will start executing and provide output in the terminal. Monitor the output for any errors, test failures, or formatting issues.

Review the Reports: Once the script finishes executing, it generates reports for each commit. Access the generated reports by opening the following URLs in a web browser:

Pytest Report: https://REPOSITORY_OWNER.github.io/REPOSITORY_NAME_REPORT/COMMIT_TIMESTAMP/pytest.html
Black Report: https://REPOSITORY_OWNER.github.io/REPOSITORY_NAME_REPORT/COMMIT_TIMESTAMP/black.html (only if formatting issues were found)
Replace REPOSITORY_OWNER with the GitHub username or organization name, REPOSITORY_NAME_REPORT with the name of the report repository, and COMMIT_TIMESTAMP with the timestamp of the commit.

Take Appropriate Actions: Based on the test and formatting results, take appropriate actions to fix any issues in the code. If necessary, create GitHub issues to track and address the problems.

Cleanup
The script automatically cleans up temporary files and directories when it finishes executing. It removes the cloned code repository, report repository, and generated reports. If you encounter any issues or need to manually clean up, you can interrupt the script using Ctrl+C to trigger the cleanup process.

Disclaimer
Use the midterm.sh script responsibly and ensure that you have the necessary permissions to perform tests and create issues on the repositories you are testing. The script is provided as-is without any warranties or guarantees.

License
This script is released under the MIT License.

Feel free to customize this README.md file according to your specific needs and preferences.
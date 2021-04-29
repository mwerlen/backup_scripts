#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


# Check the number of arguments passed.
if [ $# -ne 3 ]; then
    echo "ERROR: Wrong number of arguments"
    echo "Usage: $0 <backup_dir> <github_token> <salsa_token>"
    exit 1
fi

BACKUP_DIR="${1}"
GITHUB_TOKEN="${2}"
GITHUB_BACKUP_DIR="${BACKUP_DIR%/}/github/"
SALSA_TOKEN="${3}"
SALSA_BACKUP_DIR="${BACKUP_DIR%/}/salsa/"

LOG_FILE="/var/log/backup_git.log"
SUCCESS_FILE="/var/log/backup_git.success"

# Create backup dir
mkdir -p "${BACKUP_DIR}"
mkdir -p "${GITHUB_BACKUP_DIR}"
mkdir -p "${SALSA_BACKUP_DIR}"

# Fetch all github repos
readarray -t REPOS_GITHUB < <(\
    curl \
    --silent \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/user/repos?type=owner&per_page=100" \
    | jq \
        --compact-output \
        --raw-output \
        --arg TOKEN "${GITHUB_TOKEN}" \
        --arg DIR "${GITHUB_BACKUP_DIR}" \
        '.[] | {"name": .name,"url": (.clone_url | sub("github.com";($TOKEN+"@github.com"))), "backup_dir":$DIR}'\
)

# Fetch all salsa repo
readarray -t REPOS_SALSA < <(\
    curl \
    --silent \
    --header "PRIVATE-TOKEN: ${SALSA_TOKEN}" \
    "https://salsa.debian.org/api/v4/projects?owned=true&simple=true" \
    | jq \
        --compact-output \
        --raw-output \
        --arg TOKEN "${SALSA_TOKEN}" \
        --arg DIR "${SALSA_BACKUP_DIR}" \
        '.[] | {"name":.name,"url":(.http_url_to_repo | sub("salsa.debian.org";("oauth2:"+$TOKEN+"@salsa.debian.org"))),"backup_dir":$DIR}'\
)

REPOS=( "${REPOS_SALSA[@]}" "${REPOS_GITHUB[@]}" )

echo "------------------------------" >> "${LOG_FILE}"
date >> "${LOG_FILE}"

# Iterate over github repos
for repo in "${REPOS[@]}"
do
    name=$(echo "${repo}" | jq -r '.name')
    url=$(echo "${repo}" | jq -r '.url')
    dir=$(echo "${repo}" | jq -r '.backup_dir')

    echo "------------------------------" >> "${LOG_FILE}"
    echo "${name}" >> "${LOG_FILE}"
    
    if [[ -d "${dir}/${name}.git" ]]; then
        git --git-dir="${dir}/${name}.git" remote update --prune >> "${LOG_FILE}"
    else
        git --git-dir="${dir}/${name}.git" clone --mirror "${url}" "${dir}/${name}.git" >> "${LOG_FILE}"
    fi

    echo "" >> "${LOG_FILE}"
done

touch "${SUCCESS_FILE}"

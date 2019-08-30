#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


# Check the number of arguments passed.
if [ $# -ne 2 ]; then
    echo "ERROR: Wrong number of arguments"
    echo "Usage: $0 <github_token> <backup_dir>"
    exit 1
fi

GITHUB_TOKEN=${1}
BACKUP_DIR=${2%/}

# Create backup dir
mkdir -p "${BACKUP_DIR}"

# Fetch all github repos
readarray -t REPOS < <(curl --silent -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/user/repos?type=owner&per_page=100" | jq --compact-output --raw-output '.[] | {"name":.name,"url":.clone_url}')

# Iterate over github repos
for repo in "${REPOS[@]}"
do
    name=$(echo "${repo}" | jq -r '.name')
    url=$(echo "${repo}" | jq -r '.url')

    echo "------------------------------"
    echo "$name ($url)"
    
    if [[ -d "${BACKUP_DIR}/${name}.git" ]]; then
        git --git-dir="${BACKUP_DIR}/${name}.git" remote update --prune
    else
        git --git-dir="${BACKUP_DIR}/${name}.git" clone --mirror "${url/github.com/${GITHUB_TOKEN}@github.com}" "${BACKUP_DIR}/${name}.git"
    fi

    echo ""
done

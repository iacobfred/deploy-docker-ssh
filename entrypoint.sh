#!/bin/bash

[ -z "$INPUT_SSH_AUTH_SOCK" ] && echo "SSH_AUTH_SOCK is not set." && exit 1
[ -z "$INPUT_HOST" ] && echo "HOST is not set." && exit 1
[ -z "$INPUT_USER" ] && echo "USER is not set." && exit 1
[ -z "$INPUT_TARGET" ] && echo "TARGET is not set." && exit 1
[ -z "$INPUT_SSH_PORT" ] && echo "SSH_PORT is not set." && exit 1
[ -z "$INPUT_SSH_PRIVATE_KEY" ] && echo "SSH_PRIVATE_KEY is not set." && exit 1
[ -z "$INPUT_COMMAND" ] && echo "COMMAND is not set." && exit 1
[ -z "$GITHUB_WORKSPACE" ] && echo "GITHUB_WORKSPACE is not set." && exit 1

echo "Adding GitHub to known hosts..."
mkdir -p ~/.ssh
ssh-agent -a "$INPUT_SSH_AUTH_SOCK" > /dev/null
ssh-keyscan github.com >> ~/.ssh/known_hosts
ssh-add - <<< "$INPUT_SSH_PRIVATE_KEY"

[ -z "$INPUT_FILES" ] || {
    DIST_DIRNAME="tmp-$(date +%s)"
    DIST_DIR="${GITHUB_WORKSPACE}/${DIST_DIRNAME}"

    echo "The following files will be synced to ${INPUT_HOST}:${INPUT_TARGET}:"
    echo "${INPUT_FILES}"

    [ -d "$GITHUB_WORKSPACE" ] || {
        echo "$GITHUB_WORKSPACE is not a directory."
        exit 1
    }
    [ -w "$GITHUB_WORKSPACE" ] || {
        echo "$GITHUB_WORKSPACE is not writeable."
        exit 1
    }

    mkdir -p "$DIST_DIR"

    [ -d "$DIST_DIR" ] || {
        echo "Failed to create $DIST_DIR directory."
        exit 1
    }

    cd "$GITHUB_WORKSPACE" || {
        echo "Failed to change directory to ${GITHUB_WORKSPACE}"
        exit 1
    }
    
    # shellcheck disable=SC2206
    IFS=$' \n' read -rd '' -a files_to_transport <<< "$INPUT_FILES"

    echo "Bundling the following files to ${DIST_DIR}:"
    echo "${files_to_transport[@]}"
    for filepath in "${files_to_transport[@]}"; do
        path_to_file_dir=$(dirname "$filepath")
        cp_dest_dir="${DIST_DIR}/${path_to_file_dir}"
        mkdir -p "${cp_dest_dir}"
        [ -d "$cp_dest_dir" ] || {
            echo "Failed to create $cp_dest_dir directory"
            exit 1
        }
        echo "Copying $filepath to ${cp_dest_dir}..."
        cp -r "$filepath" "$cp_dest_dir"
    done


    echo "Prepared distribution directory with the following contents:"
    ls -a "$DIST_DIR"

    # Sync the distribution dir to the target.
    echo "Syncing distribution directory to ${INPUT_HOST}:${INPUT_TARGET}..."
    rsync -rPv -e "ssh -p $INPUT_SSH_PORT -o 'StrictHostKeyChecking no'" "${DIST_DIR}/" "${INPUT_USER}@${INPUT_HOST}:${INPUT_TARGET}"
}

echo "Starting SSH session with $INPUT_HOST..."
command="cd ${INPUT_TARGET} && ${INPUT_COMMAND}"
ssh -o StrictHostKeyChecking=no -p "$INPUT_SSH_PORT" "${INPUT_USER}@${INPUT_HOST}" "$command"

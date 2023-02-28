#!/bin/bash

# This script checks a file against a SHA256 digest file
# Usage: verify.sh [digest_file] [file_to_check]

# Check that at least one argument is given
if [ $# -lt 1 ]; then
    echo "Usage: verify.sh [digest_file] [file_to_check]"
    exit 1
fi

# Extract the filename and directory from the digest file if one or two arguments are given
if [ $# -eq 1 ]; then
    filename=$(basename "$(awk '{print $NF}' "$1")")
    directory=$(dirname "$1")
else
    filename_digest=$(basename "$(awk '{print $NF}' "$1")")
    directory_digest=$(dirname "$1")

    filename_given=$(basename "$2")
    directory_given=$(dirname "$2")

    if [ "$filename_digest" != "$filename_given" ]; then
        echo -e "\e[33mWarning: Digest file indicates file '$filename_digest', but checking '$filename_given'\e[0m"
    fi

    filename="$filename_given"
    directory="$directory_given"
fi

# Check if the file to check exists in the directory specified in the digest file
if [ ! -f "$directory/$filename" ]; then
    echo "Error: $filename not found in directory $directory"
    exit 1
fi

# Compute the SHA256 hash of the file to check
hash=$(sha256sum "$directory/$filename" | awk '{print $1}')

# Check if the computed hash matches the hash in the digest file
if [ "$hash" = "$(awk '{print $1}' "$1")" ]; then
    echo -e "\e[32mChecksums match\e[0m"
    exit 0
else
    echo -e "\e[31mError: Checksums do not match\e[0m"
    exit 1
fi

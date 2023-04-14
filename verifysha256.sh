#!/bin/sh

# This script can be used with a .DIGEST file to check the integrity of a file
# it will automatically check the file in the same directory as the DIGEST,
# first using the target name in the digest, and if that doesn't exist, by
# using the name of the digest itself.

# it was written to be POSIX compliant, including exit flags, offers a silent
# mode for use in scripting, and a less verbose mode for experienced users.

# I offer this under the MIT License:

# Copyright (c) 2023 Jesse Beard

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above cogpyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#TODO: add a warning of some sort that large files may take a long time.



# usage function
usage() {
  printf "Usage: $(basename $0) [-S|-s] <digest> [<target file>]\n"
  printf -- '-S: Silence all output\n'
  printf -- '-s: Silence output except for match or do not match\n'
  printf "no option flags can be considered verbose mode\n"
  printf "Hint: Only one argument is required if the digest is located in the same directory as the target file\n"
  exit 1
}

# file size function
check_file_size() {
    # Check if file exists
    if [ ! -e "$1" ]; then
        echo "Error: File '$1' not found when checking size."
        return 1
    fi

    # Get file size in bytes
    size=$(stat -c %s "$1")

    # Convert bytes to GB
    size_gb=$(awk "BEGIN { printf \"%.2f\", $size / 1024 / 1024 / 1024 }")

    # Print warning if file size is greater than 1 GB
    if [ $size -gt 1073741824 ]; then
        printf "\e[1;33mWarning:\033[0m File size is \033[33m%.2f GB\033[0m. This may take a while to process.\n" $size_gb
        printf "\e[1;33mProcess is currently running, not stalled, please wait!\e[0m\n"
    fi
}

# check if there are at least one argument
if [ $# -lt 1 ]; then
  usage
fi

# initialize variables
silent_mode=false
verbose_mode=true

# parse options
while getopts "Ss" opt; do
  case ${opt} in
    S )
      silent_mode=true
      verbose_mode=false
      ;;
    s )
      verbose_mode=false
      ;;
    \? )
      printf "Invalid option: -$OPTARG\n" 1>&2
      usage
      ;;
    : )
      printf "Option -$OPTARG requires an argument.\n" 1>&2
      usage
      ;;
  esac
done

shift $(($OPTIND -1))

# check if digest file exists
if [ ! -f "$1" ]; then
  if [ "$silent_mode" = false ]; then
    printf "\e[31mError:\e[0m\n Digest file does not exist.\n" >&2
    if [ "$verbose_mode" = true ]; then
      usage
    fi
  fi
  exit 1
fi

if [ ! "$(printf "$1" | grep -E '\.DIGEST$')" ]; then
    if [ "$verbose_mode" = false ]; then
      printf "\e[31mError:\e[0m\n The input file is not a .DIGEST file.\n"
    fi
    exit 1
fi

# get expected checksum
expected_checksum=$(grep -o '[[:xdigit:]]\{64\}' "$1" |  tr '[:upper:]' '[:lower:]')

# check if digest file is a valid SHA256 checksum
if [ -z "$expected_checksum" ]; then
  if [ "$verbose_mode" = true ]; then
    printf "\e[31mError:\e[0m\n The digest file does not contain a valid SHA256 checksum.\n"
  fi
  exit 1
fi



# get filename and directory from digest file
directory=$(dirname "$1")
filename=$(grep -oP '^[[:alnum:]]{64}\s*\*?\K.*?(?=s*$)' "$1")
# useful debugging tool
# printf "debug \n 1. $1 \n 2. $directory \n 3. $filename\n"

if [ -z "$filename" ]; then
  if [ "$verbose_mode" = true ]; then
    printf "\e[1;33mWarning:\e[0m Non-standard digest file doesn't include filename, using its name instead.\n"
  fi
  filename=$(basename "$1"| sed 's/\.[^.]*$//')
  #printf "here $filename $directory"
fi

# check if digest file matches second argument filename
if [ $# -eq 2 ] && [ "$filename" != "$(basename "$2")" ]; then
  if [ "$verbose_mode" = true ]; then
    printf "\e[1;33mWarning:\e[0m Digest file indicates $filename, not $(basename $2).\n"
  fi
fi

# check if file exists
if [ $# -eq 2 ] && [ ! -f "$2" ]; then
  printf "\e[31mError:\e[0m\n The target file does not exist.\n" >&2
  if [ "$verbose_mode" = true ]; then
    usage
  fi
fi

# warn the user if the filesize is larger than 1GB
# calculate actual checksum of file
if [ $# -eq 2 ]; then
  file_to_check=$2
else
  file_to_check="$directory/$filename"
fi
check_file_size "$file_to_check"
actual_checksum=$(sha256sum "$file_to_check" | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]')

# check if checksums match
if [ "$actual_checksum" = "$expected_checksum" ]; then
  if [ "$silent_mode" = false ]; then
    printf "\e[32mChecksums match!\e[0m\n"
  fi
  exit 0
else
  if [ "$silent_mode" = false ]; then
    printf "\e[31mChecksums do not match!\e[0m\n"
  fi
  exit 1
fi



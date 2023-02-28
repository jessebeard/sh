#!/bin/sh

# usage function
usage() {
  printf "Usage: $(basename $0) [-S|-s] <digest> [<target file>]\n"
  printf "-S: Silence all output\n"
  printf "-s: Silence output except for match or do not match\n"
  printf "no option flags can be considered verbose mode\n"
  printf "Hint: Only one argument is required if the digest is located in the same directory as the target file\n"
  exit 1
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
filename=$(grep -o '[^ ]*\..*$' "$1")

if [ -z "$filename" ]; then
  if [ "$verbose_mode" = true ]; then
    printf "\e[1;33mWarning:\e[0m Non-standard digest file doesn't include filename, using it's name instead.\n"
  fi
  filename=$(basename $1 | sed 's/\.[^.]*$//')
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

# calculate actual checksum of file
if [ $# -eq 2 ]; then
  actual_checksum=$(sha256sum "$2" | cut -d ' ' -f 1 |  tr '[:upper:]' '[:lower:]')
else

  actual_checksum=$(sha256sum "$directory/$filename" | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]')
fi

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

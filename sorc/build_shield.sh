#! /usr/bin/env bash
set -eux

cwd=$(pwd)

# Default settings
BUILD_TYPE="prod"
BUILD_CLEAN="clean"
COMPILER="intel"


function usage() {
  cat << EOF
Builds the SHiELD.

Usage: ${BASH_SOURCE[0]} [-n][-h][-e][-t]
  -n:
    build without clean
  -h:
    Print this help message and exit
  -e:
    Building environment
  -t:
    Building type
EOF
  exit 1
}

while getopts ":che:j:t:" option; do
  case "${option}" in
    n) BUILD_CLEAN="noclean";;
    e) COMPILER="${OPTARG}";;
    j) BUILD_JOBS="${OPTARG}";;
    t) BUILD_TYPE="${OPTARG}";;
    h)
      usage
      ;;
    :)
      echo "[${BASH_SOURCE[0]}]: ${option} requires an argument"
      usage
      ;;
    *)
      echo "[${BASH_SOURCE[0]}]: Unrecognized option: ${option}"
      usage
      ;;
  esac
done

cd "${cwd}/shield.fd/SHiELD_build"

if [ ! -d ${cwd}/shield.fd/SHiELD_SRC ]; then
  ./CHECKOUT_code_stochy
fi

cd "${cwd}/shield.fd/SHiELD_build/Build"
./COMPILE_stochy $BUILD_TYPE $BUILD_CLEAN $COMPILER

exit

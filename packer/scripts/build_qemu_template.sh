#!/bin/bash

set -e

VERSION='0.0.1'

function usage {
  echo "build_qemu_template [OPTIONS]"
}

# process our command line args
# this script requires GNU getopt, not the BSD one
if [[ "$(uname)" == "Linux" ]]; then
  GETOPT_BIN=/usr/bin/getopt
elif [[ "$(uname)" == "Darwin" ]]; then
  GETOPT_BIN=/opt/local/bin/getopt
fi

retval=0
OPTS=$($GETOPT_BIN -o r:m:hv --long packer-root:,module:,help,os-version:,version -n 'parse-options' -- "$@") || retval=$?
if [[ $retval != 0 ]] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

echo "$OPTS"
eval set -- "$OPTS"

packer_root=
module=
os_version=

while true; do
  case "$1" in
    -r | --packer-root ) packer_root="${2}"; shift; shift ;;
    -m | --module      ) module="${2}"; shift; shift ;;
    -v | --version     ) echo "$VERSION"
    --os-version       ) os_version="${2}"; shift; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

echo "Selected options:"
echo "module: $module"
echo "os version: $os_version"
echo "packer root: $packer_root"


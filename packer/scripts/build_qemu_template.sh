#!/bin/bash

set -e

VERSION='0.0.3'

# convenience variables
true=1
false=0

# some generic error codes
EPERM=1
ENOENT=2
ESRCH=3
EACCESS=13
EBUSY=16
EEXIST=17
EINVAL=22

# terminal escape code
begin_escape="\e["
end_escape="m"

# text attribute terminal codes
no_attributes="0"
bold="1"
dim="2"
underline="4"
blink="5"
inverted="7"
hidden="8"

# text attribute reset terminal codes
reset_all_attributes="0"
reset_bold="21"
reset_dim="22"
reset_underline="24"
reset_blink="25"
reset_inverted="27"
reset_hidden="28"

# text foreground terminal codes
normal_normal_foreground="39"
black_normal_foreground="30"
red_normal_foreground="31"
green_normal_foreground="32"
yellow_normal_foreground="33"
blue_normal_foreground="34"
magenta_normal_foreground="35"
cyan_normal_foreground="36"
grey_light_foreground="37"
grey_dark_foreground="90"
red_light_foreground="91"
green_light_foreground="92"
yellow_light_foreground="93"
blue_light_foreground="94"
magenta_light_foreground="95"
cyan_light_foreground="96"
white_normal_foreground="97"

# text background terminal codes
normal_normal_background="49"
black_normal_background="40"
red_normal_background="41"
green_normal_background="42"
yellow_normal_background="43"
blue_normal_background="44"
magenta_normal_background="45"
cyan_normal_background="46"
grey_light_background="47"
grey_dark_background="100"
red_light_background="101"
green_light_background="102"
yellow_light_background="103"
blue_light_background="104"
magenta_light_background="105"
cyan_light_background="106"
white_normal_background="107"

# unicode characters
heavy_circled_rightway_arrow="\u27b2"
rightway_arrow="\u2192"
copyright="\u00a9"

function usage {
  echo "build_qemu_template [OPTIONS]"
}

function print {
  local string=${1}
  local attribute=${2}
  local f_color=${3}
  local b_color=${4}

  echo -n -e "${begin_escape}${attribute};${f_color};${b_color}${end_escape}${string}${begin_escape}${no_attributes};${normal_normal_foreground};${normal_normal_background}${end_escape}"
}

function error_msg {
  local string=${1}
  local err_code=${2}

  print "build_qemu_template: $string: Exiting\n" $bold \
    $white_normal_foreground $red_normal_background
  exit $err_code
}

function about {
  print "Packer QEMU Image Builder: v$VERSION\n" $bold \
    $white_normal_foreground $normal_normal_background
  echo -e "Copyright ${copyright}2019, YggdrasilSoft, LLC."
  echo "Licensed under the Apache License, version 2.0"
  echo -n "See http://www.apache.org/licenses/LICENSE-2.0 for the text of the "
  echo "license"
}

function usage {
  local msg=${1}

  exit_code=0
  if [[ -z $msg ]]; then
    echo -e "$(basename $0): \n"
  else
    echo -e "$(basename $0): $msg\n"
    # assume that if we have a message, this is an invalid argument
    exit_code=$EINVAL
  fi
  echo "Usage:"
  echo -e "  $(basename $0) OPTIONS...\n"

  echo "Options:"
  echo "  -a|--age          The age in days before we build a new image"
  echo -n "  -r|--packer-root  The directory that contains the packer module "
  echo "directories"
  echo "  -m|--module       The module to run via packer"
  echo -n "  -o|--overwrite    Overwrite old version. Otherwise create new "
  echo "version and"
  echo -n "                    create a 'latest' symbolic link to the directory"
  echo " containing"
  echo "                    the build OS image"
  echo "  -v|--version      Print out the version of this tool"
  echo "  -h|--help         Print out this help text"
  echo -e "     --os-version   Specify the os version that should be built\n"

  about

  exit $exit_code
}

function parse_args {
  if [[ -z $packer_root ]]; then
    usage "missing required argument: Packer root must be defined"
  fi
  if [[ -z $module ]]; then
    usage "missing required argument: Module must be defined"
  fi
  if [[ -z $os_version ]]; then
    usage "missing required argument: OS version must be defined"
  fi
}

function validate_module {
  local root=${1}
  local os_version=${2}

  pushd $root 2>&1 >/dev/null
    packer validate -var-file $os_version/variables.json \
      $os_version/template.json
    packer inspect $os_version/template.json
  popd 2>&1 >/dev/null
}

function build {
  local root=${1}
  local os_version=${2}
  local overwrite=${3}

  pushd $root 2>&1 >/dev/null
    print "Current Working Directory: " $bold $white_normal_foreground \
      $normal_normal_background
    print "$(pwd)\n" $no_attributes $normal_normal_foreground \
      $normal_normal_background
    if [[ "${overwrite}" == 1 ]]; then
      packer build -force -var-file $os_version/variables.json \
        $os_version/template.json
    else
      packer build -var-file $os_version/variables.json \
        $os_version/template.json
    fi
  popd 2>&1 >/dev/null
}

function render_autoyast_file {
  local root=${1}
  local module=${2}
  local os_version=${3}

  local os_major=$(get_os_major_version $os_version)
  local os_minor=$(get_os_minor_version $os_version)
  
  # verify that rendered autoinst.xml doesn't already exist
  if [[ -f $root/http/$module/$os_major/$os_minor/autoinst.xml ]]; then
    # didn't get cleaned up last run?
    error_msg "rendered autoinst.xml file already exists" "$EEXIST"
  else
    print "${heavy_circled_rightway_arrow} Rendering autoinst.xml" $bold \
      $white_normal_foreground $normal_normal_background
  fi

  pushd $root 2>&1 >/dev/null
    if [[ ! -f $root/http/$module/$os_major/$os_minor/autoinst.xml.erb ]]; then
      error_msg "template file not found" "$ENOENT"
    fi
    if [[ ! -f $root/$module/$os_version/secrets.json ]]; then
      error_msg "secrets file not found" "$ENOENT"
    fi
    $root/scripts/process_autoyast.rb \
      -t $root/http/$module/$os_major/$os_minor/autoinst.xml.erb \
      -j $root/$module/$os_version/secrets.json \
       > $root/http/$module/$os_major/$os_minor/autoinst.xml
  popd 2>&1 >/dev/null
}

function render_vars_file {
  local root=${1}
  local module=${2}
  local os_version=${3}
  local patch=${4}
  local minor=${5}
  local major=${6}

  # verify that rendered template doesn't already exist
  if [[ -f $root/$module/$os_version/variables.json ]]; then
    # somehow this file was not cleaned out from previous runs
    # complain and exit
    error_msg "rendered variables file already exists" "$EEXIST"
  else
    print "${heavy_circled_rightway_arrow} Rendering Variables file" $bold \
      $white_normal_foreground $normal_normal_background
  fi

  options=
  if [[ "${patch}" == "$true" ]]; then
    options="--patch "
  fi
  if [[ "${minor}" == "$true" ]]; then
    options="${options} --minor "
  fi
  if [[ "${major}" == "$true" ]]; then
    options="${options} --major "
  fi

  # call the erb transformation script
  pushd $root 2>&1 >/dev/null
    # verify that the template exists
    if [[ ! -f $module/$os_version/variables.json.erb ]]; then
      error_msg "template file not found" "$ENOENT"
    fi
    if [[ ! -f $module/$os_version/secrets.json ]]; then
      error_msg "secrets file not found" "$ENOENT"
    fi
    if [[ ! -f $module/$os_version/version.json ]]; then
      error_msg "version file not found" "$ENOENT"
    fi
    if [[ ! -f $module/$os_version/metadata.json ]]; then
      error_msg "metadata file not found" "$ENOENT"
    fi
    scripts/process_variables.rb $options \
      -t $module/$os_version/variables.json.erb \
      -s $module/$os_version/secrets.json \
      -f $module/$os_version/version.json \
      -j $module/$os_version/metadata.json \
       > $module/$os_version/variables.json
  popd 2>&1 >/dev/null
}

function cleanup {
  local root=${1}
  local module=${2}
  local os_version=${3}
  
  local os_major=$(get_os_major_version $os_version)
  local os_minor=$(get_os_minor_version $os_version)

  if [[ -f $root/$module/$os_version/variables.json ]]; then
    print "Cleaning packer root..." $bold $white_normal_foreground \
      $normal_normal_background
    rm $root/$module/$os_version/variables.json
    rm $root/http/$module/$os_major/$os_minor/autoinst.xml
  else
    error_msg "File not found: rendered file missing" "$ENOENT"
  fi
}

function get_os_major_version {
  local os_version=${1}

  # assuming that OS' use a semver like version....
  echo $os_version | cut -f 1 -d '.'
}

function get_os_minor_version {
  local os_version=${1}

  echo $os_version | cut -f 2 -d '.'
}

# process our command line args
# this script requires GNU getopt, not the BSD one
if [[ "$(uname)" == "Linux" ]]; then
  GETOPT_BIN=/usr/bin/getopt
elif [[ "$(uname)" == "Darwin" ]]; then
  GETOPT_BIN=/opt/local/bin/getopt
fi

retval=0
OPTS=$($GETOPT_BIN -o a:hijm:opr:v --long age:,help,minor,major,module:,overwrite,patch,packer-root:,os-version:,version -n 'parse-options' -- "$@") || retval=$?
if [[ $retval != 0 ]] ; then echo "Failed parsing options." >&2 ; exit $EINVAL ; fi

eval set -- "$OPTS"

packer_root=
module=
overwrite=$false
os_version=
patch=$false
major=$false
minor=$false

while true; do
  case "$1" in
    -r | --packer-root ) packer_root="${2}"; shift; shift ;;
    -m | --module      ) module="${2}"; shift; shift ;;
    -o | --overwrite   ) overwrite=$true; shift;;
    -v | --version     ) echo "$VERSION"; exit;;
    -h | --help        ) usage; exit;;
    --os-version       ) os_version="${2}"; shift; shift ;;
    -p | --patch       ) patch=$true; shift; shift ;;
    -i | --minor       ) minor=$true; shift; shift ;;
    -j | --major       ) major=$true; shift; shift ;;
    --                 ) shift; break ;;
     *                 ) break ;;
  esac
done

parse_args

print "Starting Packer QEMU Image Builder: v$VERSION\n\n" $no_attributes \
  $white_normal_foreground $normal_normal_background
print "${heavy_circled_rightway_arrow} Selected options:\n" $bold \
  $white_normal_foreground $normal_normal_background
print "${rightway_arrow} module: " $bold $cyan_normal_foreground \
  $normal_normal_background
print "${module}\n" $no_attributes $normal_normal_foreground \
  $normal_normal_background
print "${rightway_arrow} os version: " $bold $cyan_normal_foreground \
  $normal_normal_background
print "${os_version}\n" $no_attributes $normal_normal_foreground \
  $normal_normal_background
print "${rightway_arrow} packer root: " $bold $cyan_normal_foreground \
  $normal_normal_background
print "${packer_root}\n" $no_attributes $normal_normal_foreground \
  $normal_normal_background
print "${rightway_arrow} overwrite: " $bold $cyan_normal_foreground \
  $normal_normal_background
if [[ "${overwrite}" == 1 ]]; then
  print "TRUE\n" $bold $green_normal_foreground $normal_normal_background
else
  print "FALSE\n" $bold $red_normal_foreground $normal_normal_background
fi

render_autoyast_file "$packer_root" "$module" "$os_version"
render_vars_file "$packer_root" "$module" "$os_version" $patch $minor $major
validate_module "$packer_root" "$module" "$os_version"
build "$packer_root/$module" "$os_version" "$overwrite"
cleanup "$packer_root/$module" "$os_version"

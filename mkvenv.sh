#!/bin/bash
#
# mkvenv.sh - a virtualenv bootstrapper
# Copyright (c) 2019 James Harmison
#
# mkvenv.sh is a small utility to help with virtualenv management for Python
#   packages with a setup.py, or for small scripts with a requirements.txt. If
#   it finds an adjacent setup.py, it will make a virtualenv and install it. If
#   it finds a requirements.txt, but no setup.py, it will use pip to install
#   the listed requirements using the default (or specified) Python
#   interpreter.
# It is designed for projects large/busy enough that venv management becomes
#   tedious, but not so big/busy that tox or something more robust would be
#   appropriate. It is primarily a development tool designed to help you get
#   a cloned repo up and running with minimal effort.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Always start with a sane place for formatter
original_dir=$(pwd)
cd $(dirname $(realpath $0))

# Figure out what we can use to download things
function which_dl() {
    if which wget 2>/dev/null; then
        return 0
    elif which curl 2>/dev/null; then
        echo "-o $1"
        return 0
    fi
    echo 'Unable to download formatter, please install wget or curl and' \
         'ensure it is in your PATH.' >&2
    exit 3
}

# Downloads a release of the output-formatter to make things pretty
if [ ! -r formatter ]; then
    formatter_url=https://raw.githubusercontent.com/solacelost/output-formatter/v1.0/formatter
    # Try to download the thing
    if ! $(which_dl formatter) "$formatter_url" 2>/dev/null; then
        echo "Unable to download formatter, please ensure you have network" \
             "connectivity and write permissions to $(pwd), or stage" \
             "formatter from the following link adjacent to mkvenv.sh:" >&2
        echo "$formatter_url" >&2
        exit 7
    fi
fi
. formatter

# From here, we should go back where you came from
cd "$original_dir"

quiet_run=''
update_only=''
get_pip=''
python=''
msg=''

function print_usage() {
    echo "usage: $0 [-h] | [-q] [-u] [-d] [-p PYTHON]"
}
function print_help() {
    print_usage
    cat << ENDOFSECTION
$(basename $0) - a virtualenv bootstrapper
Copyright (c) 2019 James Harmison

DESCRIPTION:
ENDOFSECTION
    wrap -h "Locates an adjacent setup.py or requirements.txt, creates a" \
            "virtual environment named \`venv\` with the guessed or" \
            "specified Python interpreter, and installs the package or" \
            "requirements into the virtual environment."
    echo
    wrap -h "Designed to facilitate rapid sharing of small development" \
            "for which tox (or something else robust) would be burdonsome," \
            "but sharing dependencies has already become burdonsome."
    cat << ENDOFHELP

OPTIONS:
    -h          Print this help page and exit
    -q          Suppress the banner and extra spacing/help (quiet)
    -u          Update the package only - otherwise rebuild the venv
    -d          Install the package in debug mode for easy updates
    -p PYTHON   Specify the python interpreter to build the venv with
ENDOFHELP
}

while getopts "hqudp:" opt; do
    case "$opt" in
        h)
            print_help
            exit 0
            ;;
        q)
            quiet_run=true
            ;;
        u)
            update_only=true
            ;;
        d)
            develop_mode=true
            ;;
        p)
            python="${OPTARG[@]}"
            $python -m pip --help &>/dev/null || get_pip=true
            ;;
        *)
            print_usage >&2
            exit 1
            ;;
    esac
done

# We really want setup.py or requirements.txt
if [ ! -e setup.py -a ! -e requirements.txt ]; then
    wrap "No setup.py or requirements.txt detected adacent to the script in" \
         "$(pwd), check \`$0 -h\` for more information." >&2
    exit 1
fi

# Shorted than writing the fmt every time
function now() {
    date '+%Y%m%dT%H%M%S'
}

# ERR cleanup helper
function on_error() {
    [ -n "$msg" ] && wrap "$msg" ||:
    echo
    now=$(now)
    mv $log "$original_dir/mkvenv_error_$now.log"
    sync
    wrap "Error on mkvenv.sh line $1, logs available at" \
         "$original_dir/mkvenv_error_$now.log" >&2
    exit $2
}

# Look for things
function in_path() {
    which "${@}" &>/dev/null
    return $?
}

# Try to find the right python if it's not specified, but always accept any
# cli-passed value first as "probably right" and let the user deal with the
# consequences of their actions.
function check_python() {
    if [ -z "$python" ]; then
        if grep -qF 'Python :: 3' setup.py; then # assume we need python3
            if in_path python3; then
                python=python3
            elif ! in_path python; then
                echo 'No python detected, unable to continue'
                exit 1
            elif python --version | grep -qF '^Python 3'; then
                python=python
            elif grep -qF 'Python :: 2' setup.py; then # python2 acceptable
                python=python
            else
                echo "No suitable version of python found for setup.py, " \
                     "consider specifying path manually (check \`$0 -h\` " \
                     "for more information)"
                exit 1
            fi
        else # Just find python of some sort
            if in_path python; then # Just trust whatever the system/user has
                python=python
            elif in_path python3; then # We should prefer 3 tbh
                python=python3
            elif in_path python2; then # Last resort
                python=python2
            else
                echo "No suitable version of python found for setup.py, " \
                     "consider specifying path manually (check \`$0 -h\` " \
                     "for more information)"
                exit 1
            fi
        fi
    fi
    echo "Identified python: $python"
    # As an aside - do you guys have pip?
    $python -m pip --help &>/dev/null || get_pip=true
    $python -m virtualenv --help &>/dev/null || get_pip=true
    $python -c 'import setuptools' --help &>/dev/null || get_pip=true
    [ -n "$get_pip" ] && echo "pip needs installed" || echo "pip is installed"
}

# Some people don't have pip installed and virtualenv/setuptools configured?
# What is this, 1910? Whatever, we'll fix it.
function install_pip() {
    local get_pip_url=https://bootstrap.pypa.io/get-pip.py
    if ! $(which_dl get-pip.py) "$get_pip_url" ; then
        msg=$(echo "Unable to download the pip installation bootstrapper, " \
              "ensure that you have internet access, or install pip via" \
              "some other mechanism.")
        return 1
    elif ! $python get-pip.py --user ; then
        msg=$(echo "Unable to install pip in user mode, ensure that you " \
              "have at least $python-distutils installed through your " \
              "operating system package manager (yum, apt, etc.)")
        return 2
    fi
    $python -m pip install --user --upgrade pip virtualenv setuptools \
        || return 3
}

# Stage some logging
log=$(mktemp)
exec 7>$log
echo "Logging initialized $(now)" >&7

# Set some traps
trap 'on_error $LINENO $?' ERR
trap 'rm -f $log' EXIT


# Showtime
if [ -z "$quiet_run" ]; then
    center_border_text 'Virtual Environment Creator'
    echo
fi

# Try to clean up environment variables and whatnot
if [ -z "$update_only" ]; then # Burn it to the ground
    warn_run 'Checking for (and unsetting) existing virtualenv' \
        '[ -n "$VIRTUAL_ENV" ] && { deactivate ; false ; } ||:'
    error_run 'Removing old virtual environment (if it exists)' rm -rf venv
fi

# Smart python detection
error_run 'Identifying python interpreter to use' check_python
if [ -n "$get_pip" ]; then # you should feel ashamed
    error_run 'Installing pip, virtualenv, and setuptools in pip user mode' \
        install_pip
fi

if [ -r setup.py ]; then
    # Try to read setup.py, see what we can find
    error_run 'Checking for valid setup.py' \
        'pkg_name=$($python ./setup.py --name)'
fi

if [ -z "$update_only" ]; then # let's make it
    error_run "Making $python virtual environment" \
        "$python -m virtualenv -p $python venv"
else # Make sure it's set up
    error_run "Checking for existing $python virtual environment" \
        [ -x venv/bin/python ]
    if [ -r setup.py ]; then
        # and clean
        error_run "Removing old site-package for $pkg_name" \
            "rm -rf venv/lib/python*/site-packages/$pkg_name{.egg,.egg-link}"
    fi
fi
# Ensure everything's up to date, infrastructure-wise
error_run 'Updating base venv packages' \
    venv/bin/python -m pip install --upgrade pip virtualenv setuptools

# Hard requirements definitions handled
if [ -r requirements.txt ]; then
    error_run "Installing requirements" \
        venv/bin/python -m pip install -r requirements.txt
fi

if [ -r setup.py ]; then
    # Actual installation
    if [ -n "$develop_mode" ]; then # egg-link mode
        error_run "Linking $pkg_name to venv in develop mode" \
            venv/bin/python ./setup.py develop
    else # Normal distutils sdist/setuptools egg installation mode
        error_run "Installing $pkg_name to venv" \
            venv/bin/python ./setup.py install
    fi
fi

if [ -z "$quiet_run" ]; then
    echo
    wrap "Your virtualenv should be ready to go. To use it, ensure you" \
        "activate the virtualenv either in your Python or, for example," \
        "in the shell with:"
    echo ". $original_dir/venv/bin/activate"
fi

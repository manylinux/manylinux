#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh


CPYTHON_VERSION=$1
CPYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python


function pyver_dist_dir {
	# Echoes the dist directory name of given pyver, removing alpha/beta prerelease
	# Thus:
	# 3.2.1   -> 3.2.1
	# 3.7.0b4 -> 3.7.0
	echo $1 | awk -F "." '{printf "%d.%d.%d", $1, $2, $3}'
}


CPYTHON_DIST_DIR=$(pyver_dist_dir ${CPYTHON_VERSION})
fetch_source Python-${CPYTHON_VERSION}.tgz ${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}
fetch_source Python-${CPYTHON_VERSION}.tgz.asc ${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}
gpg --verify Python-${CPYTHON_VERSION}.tgz.asc
tar -xzf Python-${CPYTHON_VERSION}.tgz
pushd Python-${CPYTHON_VERSION}
PREFIX="/opt/_internal/cpython-${CPYTHON_VERSION}"
mkdir -p ${PREFIX}/lib
./configure --prefix=${PREFIX} --disable-shared > /dev/null
make -j$(nproc) > /dev/null
make -j$(nproc) install > /dev/null
popd
rm -rf Python-${CPYTHON_VERSION} Python-${CPYTHON_VERSION}.tgz Python-${CPYTHON_VERSION}.tgz.asc

# we don't need libpython*.a, and they're many megabytes
find ${PREFIX} -name '*.a' -print0 | xargs -0 rm -f

# We do not need the Python test suites
find ${PREFIX} -depth \( -type d -a -name test -o -name tests \) | xargs rm -rf

# Strip ELF files found in ${PREFIX}
strip_ ${PREFIX}

# Some python's install as bin/python3. Make them available as bin/python.
if [ -e ${PREFIX}/bin/python3 ] && [ ! -e ${PREFIX}/bin/python ]; then
	ln -s python3 ${PREFIX}/bin/python
fi
${PREFIX}/bin/python -m ensurepip
if [ -e ${PREFIX}/bin/pip3 ] && [ ! -e ${PREFIX}/bin/pip ]; then
	ln -s pip3 ${PREFIX}/bin/pip
fi

# We do not need precompiled .pyc and .pyo files.
clean_pyc ${PREFIX}

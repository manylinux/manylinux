#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Export variable needed by 'docker build --build-arg'
export POLICY
export PLATFORM

# get docker default multiarch image prefix for PLATFORM
if [ "${PLATFORM}" == "x86_64" ]; then
	MULTIARCH_PREFIX="amd64/"
elif [ "${PLATFORM}" == "i686" ]; then
	MULTIARCH_PREFIX="i386/"
elif [ "${PLATFORM}" == "aarch64" ]; then
	MULTIARCH_PREFIX="arm64v8/"
elif [ "${PLATFORM}" == "ppc64le" ]; then
	MULTIARCH_PREFIX="ppc64le/"
elif [ "${PLATFORM}" == "s390x" ]; then
	MULTIARCH_PREFIX="s390x/"
else
	echo "Unsupported platform: '${PLATFORM}'"
	exit 1
fi

# setup BASEIMAGE and its specific properties
if [ "${POLICY}" == "manylinux2010" ]; then
	if [ "${PLATFORM}" == "x86_64" ]; then
		BASEIMAGE="quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall"
	elif [ "${PLATFORM}" == "i686" ]; then
		BASEIMAGE="${MULTIARCH_PREFIX}centos:6"
	else
		echo "Policy '${POLICY}' does not support platform '${PLATFORM}'"
		exit 1
	fi
	DEVTOOLSET_ROOTPATH="/opt/rh/devtoolset-8/root"
	PREPEND_PATH="${DEVTOOLSET_ROOTPATH}/usr/bin:"
	if [ "${PLATFORM}" == "i686" ]; then
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst:/usr/local/lib"
	else
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst:/usr/local/lib64:/usr/local/lib"
	fi
elif [ "${POLICY}" == "manylinux2014" ]; then
	if [ "${PLATFORM}" == "s390x" ]; then
		BASEIMAGE="s390x/clefos:7"
	else
		BASEIMAGE="${MULTIARCH_PREFIX}centos:7"
	fi
	DEVTOOLSET_ROOTPATH="/opt/rh/devtoolset-9/root"
	PREPEND_PATH="${DEVTOOLSET_ROOTPATH}/usr/bin:"
	if [ "${PLATFORM}" == "i686" ]; then
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst:/usr/local/lib"
	else
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst:/usr/local/lib64:/usr/local/lib"
	fi
else
	echo "Unsupported policy: '${POLICY}'"
	exit 1
fi
export BASEIMAGE
export DEVTOOLSET_ROOTPATH
export PREPEND_PATH
export LD_LIBRARY_PATH_ARG

docker build \
	--build-arg POLICY --build-arg PLATFORM --build-arg BASEIMAGE \
	--build-arg DEVTOOLSET_ROOTPATH --build-arg PREPEND_PATH --build-arg LD_LIBRARY_PATH_ARG \
	--rm -t quay.io/pypa/${POLICY}_${PLATFORM}:${TRAVIS_COMMIT} \
	-f docker/Dockerfile docker/

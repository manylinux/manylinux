#!/usr/bin/env bash
set -e -u -x -o pipefail

basedir=$(dirname "$0")

docker_build() {
    # Output something every 10 minutes or Travis kills the job
    while sleep 9m; do echo -n -e " \b"; done &
    sleep_loop_pid=$!
    docker build --rm "$@" "$basedir"
    kill "$sleep_loop_pid"
}

case "${1-}" in
32)
    docker_build \
        -f "$basedir/Dockerfile-i686" \
        -t quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build32:latest \
        --cache-from quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build32:latest
    ;;
64)
    docker_build \
        -f "$basedir/Dockerfile-x86_64" \
        -t quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build64:latest \
        --cache-from quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build64:latest
    ;;
all)
    docker_build \
        --target manylinux2010_x86_64_centos6_no_vsyscall_build \
        -t quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build:latest \
        --cache-from quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build32:latest \
        --cache-from quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build64:latest \
        --cache-from quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build:latest
    docker_build \
        -t quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall:latest \
        --cache-from quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build:latest \
        --cache-from quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall:latest
    ;;
*)
    echo "Usage: $0 {32|64|all}" >&2
    exit 1
    ;;
esac

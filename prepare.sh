#!/bin/bash
#

set -ex

BASE_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)

while [[ $# > 0 ]]; do
    lowerI="$(echo $1 | awk '{print tolower($0)}')"
    case $lowerI in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Global Options:"
            echo -e "  -h, --help  \t Show this help message and exit"
            echo -e "  --app_version  \t 1Panel version"
            echo -e "  --docker_version  \t Docker version"
            echo -e "  --compose_version  \t Docker-compose version"
            exit 0
            ;;
        --app_version)
            app_version=$2
            shift
            ;;
        --docker_version)
            docker_version=$2
            shift
            ;;
        --compose_version)
            compose_version=$2
            shift
            ;;
        *)
            echo "install: Unknown option $1"
            echo "eg: $0 --app_version v1.7.4 --docker_version 24.0.7 --compose_version v2.23.0"
            exit 1
            ;;
    esac
    shift
done

APP_VERSION=${app_version:-v1.7.4}
DOCKER_VERSION=${docker_version:-20.10.7}
COMPOSE_VERSION=${compose_version:-v2.23.0}

if [ -d "build" ]; then
    rm -rf build/*
fi

for architecture in x86_64 aarch64 s390x ppc64le loongarch64; do
    cd "${BASE_DIR}" || exit 1

    if [ "${architecture}" == "x86_64" ]; then
        arch="amd64"
    fi
    if [ "${architecture}" == "aarch64" ]; then
        arch="arm64"
    fi
    if [ "${architecture}" == "loongarch64" ]; then
        arch="loong64"
    fi
    if [ "${architecture}" == "s390x" ]; then
        arch="s390x"
    fi
    if [ "${architecture}" == "ppc64le" ]; then
        arch="ppc64le"
    fi

    APP_BIN_URL="https://github.com/wanghe-fit2cloud/1Panel/releases/download/${APP_VERSION}/1panel-${APP_VERSION}-linux-${arch}.tar.gz"
    DOCKER_BIN_URL="https://download.docker.com/linux/static/stable/${architecture}/docker-${DOCKER_VERSION}.tgz"
    COMPOSE_BIN_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${architecture}"
    if [ "${architecture}" == "loongarch64" ]; then
        APP_BIN_URL="https://github.com/wojiushixiaobai/1Panel-${architecture}/releases/download/${APP_VERSION}/1panel-${APP_VERSION}-linux-${arch}.tar.gz"
        DOCKER_BIN_URL="https://github.com/wojiushixiaobai/docker-ce-binaries-${architecture}/releases/download/v${DOCKER_VERSION}/docker-${DOCKER_VERSION}.tgz"
        COMPOSE_BIN_URL="https://github.com/wojiushixiaobai/compose-${architecture}/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${architecture}"
    fi
    if [ "${architecture}" == "s390x" ]; then
        DOCKER_BIN_URL="https://github.com/wojiushixiaobai/docker-ce-binaries-${architecture}/releases/download/v${DOCKER_VERSION}/docker-${DOCKER_VERSION}.tgz"
    fi
    if [ "${architecture}" == "ppc64le" ]; then
        DOCKER_BIN_URL="https://download.docker.com/linux/static/stable/${architecture}/docker-18.06.3-ce.tgz"
    fi

    BUILD_NAME=1panel-${APP_VERSION}-linux-${arch}
    BUILD_DIR=build/${APP_VERSION}/${BUILD_NAME}
    mkdir -p "${BUILD_DIR}"

    BUILD_OFFLINE_NAME=1panel-${APP_VERSION}-offline-linux-${arch}
    BUILD_OFFLINE_DIR=build/${APP_VERSION}/${BUILD_OFFLINE_NAME}
    mkdir -p "${BUILD_OFFLINE_DIR}"

    if [ ! -f "build/1panel-${APP_VERSION}-linux-${arch}.tar.gz" ]; then
        wget -q "${APP_BIN_URL}" -O "build/1panel-${APP_VERSION}-linux-${arch}.tar.gz"
    fi
    tar -xf "build/1panel-${APP_VERSION}-linux-${arch}.tar.gz" -C "${BUILD_DIR}" --strip-components=1
    tar -xf "build/1panel-${APP_VERSION}-linux-${arch}.tar.gz" -C "${BUILD_OFFLINE_DIR}" --strip-components=1
    rm -f "${BUILD_DIR}/install.sh"
    rm -f "${BUILD_OFFLINE_DIR}/install.sh"

    if [ ! -f "${BUILD_OFFLINE_DIR}/docker.tgz" ]; then
        wget -q "${DOCKER_BIN_URL}" -O "${BUILD_OFFLINE_DIR}/docker.tgz"
    fi

    if [ ! -f "${BUILD_OFFLINE_DIR}/docker-compose" ]; then
        wget -q "${COMPOSE_BIN_URL}" -O "${BUILD_OFFLINE_DIR}/docker-compose"
    fi

    cp -f docker.service "${BUILD_DIR}"
    cp -f docker.service "${BUILD_OFFLINE_DIR}"
    cp -f install.sh "${BUILD_DIR}"
    cp -f install.sh "${BUILD_OFFLINE_DIR}"
    chmod +x "${BUILD_OFFLINE_DIR}/docker-compose"
    chmod +x "${BUILD_DIR}/install.sh" "${BUILD_OFFLINE_DIR}/install.sh"

    cd "build/${APP_VERSION}" || exit 1
    tar -zcf "${BUILD_NAME}.tar.gz" "${BUILD_NAME}"
    tar -zcf "${BUILD_OFFLINE_NAME}.tar.gz" "${BUILD_OFFLINE_NAME}"
done

cd "${BASE_DIR}/build/${APP_VERSION}" || exit 1
sha256sum 1panel-*.tar.gz > checksums.txt
ls -al "${BASE_DIR}/build/${APP_VERSION}"
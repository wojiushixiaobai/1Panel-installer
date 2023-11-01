#!/bin/bash
#

BASE_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)

cd "${BASE_DIR}" || exit 1

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

for architecture in x86_64 aarch64 s390 ppc64le loongaech64; do
    if [ "${architecture}" == "x86_64" ]; then
        arch="amd64"
    fi
    if [ "${architecture}" == "aarch64" ]; then
        arch="arm64"
    fi
    if [ "${architecture}" == "loongarch64" ]; then
        arch="loong64"
    fi
    if [ "${architecture}" == "s390" ]; then
        arch="s390x"
    fi
    if [ "${architecture}" == "ppc64le" ]; then
        arch="ppc64le"
    fi

    APP_BIN_URL="https://github.com/wanghe-fit2cloud/1Panel/releases/download/${APP_VERSION}/1panel-${APP_VERSION}-linux-${arch}.tar.gz"
    DOCKER_BIN_URL="https://download.docker.com/linux/static/stable/${architecture}/docker-${DOCKER_VERSION}.tgz"
    COMPOSE_BIN_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${architecture}"
    if [ "${architecture}" == "loongarch64" ]; then
        APP_BIN_URL="https://github.com/wojiushixiaobai/1Panel-loongarch64/releases/download/${APP_VERSION}/1panel-${APP_VERSION}-linux-${arch}.tar.gz"
        DOCKER_BIN_URL="https://github.com/wojiushixiaobai/docker-ce-binaries-loongarch64/releases/download/${DOCKER_VERSION}/docker-${DOCKER_VERSION}.tgz"
        COMPOSE_BIN_URL="https://github.com/wojiushixiaobai/compose-loongarch64/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${architecture}"
    fi

    if [ ! -d "build/${APP_VERSION}/1panel-offine-linux-${arch}" ]; then
        mkdir -p "build/${APP_VERSION}/1panel-offine-linux-${arch}"
    fi

    if [ ! -f "build/1panel-${APP_VERSION}-linux-${arch}.tar.gz" ]; then
        wget "${APP_BIN_URL}" -O "build/1panel-${APP_VERSION}-linux-${arch}.tar.gz"
    fi
    tar -xf "build/1panel-${APP_VERSION}-linux-${arch}.tar.gz" -C "build/${APP_VERSION}/1panel-offine-linux-${arch}" --strip-components=1
    rm -f "build/${APP_VERSION}/1panel-offine-linux-${arch}/install.sh"

    if [ ! -f "build/${APP_VERSION}/1panel-offine-linux-${arch}/docker.tar.gz" ]; then
        wget "${DOCKER_BIN_URL}" -O "build/${APP_VERSION}/1panel-offine-linux-${arch}/docker.tar.gz"
    fi

    if [ ! -f "build/${APP_VERSION}/1panel-offine-linux-${arch}/docker-compose" ]; then
        wget "${COMPOSE_BIN_URL}" -O "build/${APP_VERSION}/1panel-offine-linux-${arch}/docker-compose"
    fi

    cp -f install.sh "build/${APP_VERSION}/1panel-offine-linux-${arch}"
    chmod +x "build/${APP_VERSION}/linux-${architecture}/docker-compose"

    cd "build/${APP_VERSION}" || exit 1

    if [ -f "1panel-offine-linux-${arch}.tar.gz" ]; then
        rm -f "1panel-offine-linux-${arch}.tar.gz"
    fi
    tar -zcf "1panel-offine-linux-${arch}.tar.gz" "1panel-offine-linux-${arch}"
done

cd "${BASE_DIR}/build/${APP_VERSION}" || exit 1
sha256sum 1panel-offine-linux-*.tar.gz > checksums.txt
#!/bin/bash

PROJECT_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)
cd "${PROJECT_DIR}" || exit 1

if [ ! "$(echo $PATH | grep /usr/local/bin)" ]; then
    export PATH=/usr/local/bin:$PATH
fi

tmp_dir=$(mktemp -d)

if [ -f "/usr/bin/1pctl" ]; then
    mv /usr/bin/1pctl ${tmp_dir}/1pctl
    rm -f /usr/bin/1pctl /usr/local/bin/1pctl
    mv ${tmp_dir}/1pctl /usr/local/bin
    sed -i -e "s#/usr/bin#/usr/local/bin#g" /usr/local/bin/1pctl
fi

if [ -f "/usr/bin/1panel" ]; then
    mv /usr/bin/1panel ${tmp_dir}/1panel
    rm -f /usr/bin/1panel /usr/local/bin/1panel
    mv ${tmp_dir}/1panel /usr/local/bin
    sed -i -e "s#/usr/bin#/usr/local/bin#g" /etc/systemd/system/1panel.service
    systemctl daemon-reload
fi

if [ -f "/usr/local/bin/1pctl" ]; then
    VERSION=$(grep "ORIGINAL_VERSION=" 1pctl | awk -F "=" '{print $2}')
    ORIGINAL_VERSION=$(grep "ORIGINAL_VERSION=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_PORT=$(grep "ORIGINAL_PORT=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_USER=$(grep "ORIGINAL_USERNAME=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_PASSWORD=$(grep "ORIGINAL_PASSWORD=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_ENTRANCE=$(grep "ORIGINAL_ENTRANCE=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    INSTALL_DIR=$(grep "BASE_DIR=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
else
    echo -e "\033[31m[ERROR]: 1Panel is not installed \033[0m"
    exit 1
fi

if [ "${VERSION}" == "${ORIGINAL_VERSION}" ]; then
    echo -e "\033[33m[WARN]: 1Panel is already the latest version \033[0m"
    exit 0
fi

function echo_logo() {
    cat << EOF
    ██╗    ██████╗  █████╗ ███╗   ██╗███████╗██╗
   ███║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║
   ╚██║    ██████╔╝███████║██╔██╗ ██║█████╗  ██║
    ██║    ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║
    ██║    ██║     ██║  ██║██║ ╚████║███████╗███████╗
    ╚═╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
EOF
    echo
    echo -e "\t\t\t   Version: \033[33m ${ORIGINAL_VERSION} -> ${VERSION} \033[0m \n"
}

function check_docker() {
    if [ -f "docker.tgz" ] && [ -f "docker.service" ]; then
        if [ -d "docker" ]; then
            rm -rf docker/*
        fi
        if [ -f "/usr/local/bin/docker" ] && [ -f "/etc/systemd/system/docker.service" ]; then
            tar xf docker.tgz
            if [ "$(md5sum /usr/local/bin/docker | awk '{print $1}')" != "$(md5sum docker/docker | awk '{print $1}')" ]; then
                upgrade_docker
            fi
        fi
    fi
}

function upgrade_docker() {
    if docker ps >/dev/null 2>&1; then
        systemctl stop docker
    fi
    if ! diff docker.service /etc/systemd/system/docker.service >/dev/null 2>&1; then
        cp docker.service /etc/systemd/system
        systemctl daemon-reload
    fi
    chown -R root:root docker
    chmod -R 755 docker
    cp -f docker/* /usr/local/bin
    systemctl daemon-reload
    systemctl start docker
}

function check_compose() {
    if [ -f "docker-compose" ]; then
        if [ -f "/usr/local/bin/docker-compose" ]; then
            if [ "$(md5sum /usr/local/bin/docker-compose | awk '{print $1}')" != "$(md5sum docker-compose | awk '{print $1}')" ]; then
                upgrade_compose
            fi
        fi
    fi
}

function upgrade_compose() {
    chown root:root docker-compose
    chmod 755 docker-compose
    cp -f docker-compose /usr/local/bin
}

function check_1panel() {
    if [ -f "1panel" ] && [ -f "1panel.service" ]; then
        if [ -f "/usr/local/bin/1panel" ]; then
            if [ "$(md5sum /usr/local/bin/1panel | awk '{print $1}')" != "$(md5sum 1panel | awk '{print $1}')" ]; then
                upgrade_1panel
                upgrade_1pctl
            fi
        fi
    fi
}

function upgrade_1panel() {
    if systemctl status 1panel | grep "running" >/dev/null 2>&1; then
        systemctl stop 1panel
    fi
    if ! diff 1panel.service /etc/systemd/system/1panel.service >/dev/null 2>&1; then
        cp -f 1panel.service /etc/systemd/system
        systemctl daemon-reload
    fi
    if [ -d "/usr/local/bin/lang" ]; then
        rm -rf /usr/local/bin/lang
    fi
    cp -rf lang /usr/local/bin
    cp -f 1panel /usr/local/bin
    chown root:root /usr/local/bin/1panel
    chmod 700 /usr/local/bin/1panel
    systemctl start 1panel
}

function upgrade_1pctl() {
    cp -f 1pctl /usr/local/bin
    chown root:root /usr/local/bin/1pctl
    chmod 700 /usr/local/bin/1pctl
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${INSTALL_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${PANEL_USER}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${PANEL_PASSWORD}#g" /usr/local/bin/1pctl
    if [ -z "${PANEL_ENTRANCE}" ]; then
        sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=''#g" /usr/local/bin/1pctl
    else
        sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    fi
}

function get_host_ip() {
  local default_ip="127.0.0.1"
  host=$(command -v hostname &>/dev/null && hostname -I | cut -d ' ' -f1)
  if [ ! "${host}" ]; then
      host=$(command -v ip &>/dev/null && ip addr | grep 'inet ' | grep -Ev '(127.0.0.1|inet6|docker)' | awk '{print $2}' | head -n 1 | cut -d / -f1)
  fi
  if [[ ${host} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "${host}"
  else
      echo "${default_ip}"
  fi
}

function post_upgrade() {
    echo ""
    PANEL_HOST=$(get_host_ip)
    if [[ -z "${PANEL_HOST}" ]]; then
        PANEL_HOST="127.0.0.1"
    fi

    echo "================ 感谢您的耐心等待, 升级已经完成 ================="
    echo ""
    echo -e "面板地址:\033[33m http://${PANEL_HOST}:${PANEL_PORT}/${PANEL_ENTRANCE} \033[0m"
    echo ""
    echo "项目官网: https://1panel.cn"
    echo "项目文档: https://1panel.cn/docs"
    echo "代码仓库: https://github.com/1Panel-dev/1Panel"
    echo "交流社区: https://bbs.fit2cloud.com"
    echo ""

    echo -e "\033[33m 如果使用的是云服务器, 请至安全组开放 $PANEL_PORT 端口 \033[0m"
    echo ""
    echo "================================================================="
}

function main() {
    echo_logo
    check_docker
    check_compose
    check_1panel
    post_upgrade
}

main
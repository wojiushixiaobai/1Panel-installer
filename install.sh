#!/bin/bash
#

PROJECT_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)
cd "${PROJECT_DIR}" || exit 1

VERSION=v1.10.12-lts

if [ ! "$(echo $PATH | grep /usr/local/bin)" ]; then
    export PATH=/usr/local/bin:$PATH
fi

while [[ $# > 0 ]]; do
    lowerI="$(echo $1 | awk '{print tolower($0)}')"
    case $lowerI in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Global Options:"
            echo -e "  -h, --help  \t Show this help message and exit"
            echo -e "  -v, --version  Show the version information"
            echo -e "  --port  \t Configure web access port in the Installation Phase."
            echo -e "  --user  \t Configure 1Panel user in the Installation Phase."
            echo -e "  --password  \t Configure 1Panel password in the Installation Phase."
            echo -e "  --entrance  \t Configure 1Panel web security access in the Installation Phase."
            echo -e "  --install-dir  Configure 1Panel install directory in the Installation Phase."
            echo
            echo "For more help options on how to use 1Panel, head to https://1panel.cn/docs/"
            exit 0
            ;;
        -v|--version)
            echo "1Panel-installer version: $VERSION"
            exit 0
            ;;
        --port)
            PANEL_PORT=$2
            shift
            ;;
        --user)
            PANEL_USER=$2
            shift
            ;;
        --password)
            PANEL_PASSWORD=$2
            shift
            ;;
        --entrance)
            PANEL_ENTRANCE=$2
            shift
            ;;
        --install-dir)
            INSTALL_DIR=$2
            shift
            ;;
        *)
            echo "install: Unknown option $1"
            echo "eg: $0 --port 8888 --user admin --password ******** --entrance secret"
            exit 1
            ;;
    esac
    shift
done

PANEL_PORT=${PANEL_PORT:-"8888"}
PANEL_USER=${PANEL_USER:-"admin"}
PANEL_PASSWORD=${PANEL_PASSWORD:-""}
PANEL_ENTRANCE=${PANEL_ENTRANCE:-"secret"}
INSTALL_DIR=${INSTALL_DIR:-"/opt/1panel"}
INSTALL_CHECK=0

if [ -f "/usr/local/bin/1pctl" ] && [ "${INSTALL_CHECK}" == "0" ]; then
    VERSION=$(grep "ORIGINAL_VERSION=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_PORT=$(grep "ORIGINAL_PORT=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_USER=$(grep "ORIGINAL_USERNAME=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_PASSWORD=$(grep "ORIGINAL_PASSWORD=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    PANEL_ENTRANCE=$(grep "ORIGINAL_ENTRANCE=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    INSTALL_DIR=$(grep "BASE_DIR=" /usr/local/bin/1pctl | awk -F "=" '{print $2}')
    INSTALL_CHECK=1
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
    echo -e "\t\t\t\t   Version: \033[33m $VERSION \033[0m \n"
}

function log_warn() {
    echo -e "\033[33m[WARN]: $1 \033[0m"
}

function log_error() {
    echo -e "\033[31m[ERROR]: $1 \033[0m"
}

function check_os() {
    if [ "$(uname -s)" != "Linux" ]; then
        log_error "1Panel only support Linux"
        exit 1
    fi
}

function check_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log_error "systemctl: command not found"
        exit 1
    fi
}

function check_prepare(){
     for app in tar iptables; do
        if ! command -v $app >/dev/null 2>&1; then
            echo "$app: command not found"
            exit 1
        fi
    done
    if [ ! -d "${INSTALL_DIR}" ]; then
        mkdir -p "${INSTALL_DIR}"
    fi
}

function check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi
    if ! docker ps >/dev/null 2>&1; then
        systemctl start docker
    fi
}

function install_docker() {
    if [ ! -f "docker.tgz" ]; then
        log_error "docker.tgz not found"
        exit 1
    fi
    if [ ! -f "docker.service" ]; then
        log_error "docker.service not found"
        exit 1
    fi
    if [ ! -f "/etc/systemd/system/docker.service" ]; then
        cp docker.service /etc/systemd/system
    fi
    tar -xf docker.tgz
    chown -R root:root docker
    chmod -R 755 docker
    cp -f docker/* /usr/local/bin
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker
}

function check_compose() {
    if ! command -v docker-compose >/dev/null 2>&1; then
        install_compose
    fi
}

function install_compose() {
    if [ ! -f "docker-compose" ]; then
        log_error "docker-compose not found"
        exit 1
    fi
    chown root:root docker-compose
    chmod 755 docker-compose
    cp -f docker-compose /usr/local/bin
}

function check_1panel() {
    if ! command -v 1panel >/dev/null 2>&1; then
        install_1panel
    fi
    if command -v firewall-cmd >/dev/null; then
        if firewall-cmd --state >/dev/null 2>&1; then
            if ! firewall-cmd --list-all | grep "${PANEL_PORT}" >/dev/null 2>&1; then
                firewall-cmd --zone=public --add-port="${PANEL_PORT}/tcp" --permanent
                firewall-cmd --reload
            fi
        fi
    fi
    if which ufw >/dev/null 2>&1; then
        if ufw status | grep "Status: active" >/dev/null 2>&1; then
            if ! ufw status | grep "${PANEL_PORT}/tcp" | grep "ALLOW" >/dev/null 2>&1; then
                ufw allow "${PANEL_PORT}/tcp"
                ufw reload
            fi
        fi
    fi
    if ! systemctl status 1panel | grep "running" >/dev/null 2>&1; then
        systemctl start 1panel
    fi
}

function install_1panel() {
    if [ ! -f "1panel" ]; then
        log_error "1panel not found"
        exit 1
    fi
    if [ ! -f "1panel.service" ]; then
        log_error "1panel.service not found"
        exit 1
    fi
    if [ ! -f "/etc/systemd/system/1panel.service" ]; then
        cp 1panel.service /etc/systemd/system
    fi
    cp -f 1panel /usr/local/bin
    chown root:root /usr/local/bin/1panel
    chmod 700 /usr/local/bin/1panel
    systemctl daemon-reload
    systemctl enable 1panel
    systemctl start 1panel
}

function check_1pctl() {
    if ! command -v 1pctl >/dev/null 2>&1; then
        install_1pctl
    fi
}

function install_1pctl() {
    if [ ! -f "1pctl" ]; then
        log_error "1pctl not found"
        exit 1
    fi
    if [ ! -f "/usr/local/bin/1pctl" ]; then
        cp -f 1pctl /usr/local/bin
    fi
    chown root:root /usr/local/bin/1pctl
    chmod 700 /usr/local/bin/1pctl
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${INSTALL_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${PANEL_USER}#g" /usr/local/bin/1pctl

    if [ -z "${PANEL_PASSWORD}" ]; then
        PANEL_PASSWORD=$(random_str 24)
    fi
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${PANEL_PASSWORD}#g" /usr/local/bin/1pctl
    if [ -z "${PANEL_ENTRANCE}" ]; then
        sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=''#g" /usr/local/bin/1pctl
    else
        sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    fi
}

function random_str() {
  len=$1
  if [[ -z ${len} ]]; then
    len=24
  fi
  uuid=None
  if command -v dmidecode &>/dev/null; then
    if [[ ${len} > 16 ]]; then
      uuid=$(dmidecode -t 1 | grep UUID | awk '{print $2}' | sha256sum | awk '{print $1}' | head -c ${len})
    fi
  fi
  if [[ "${#uuid}" == "${len}" ]]; then
    echo "${uuid}"
  else
    head -c100 < /dev/urandom | base64 | tr -dc A-Za-z0-9 | head -c ${len}; echo
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

function post_install() {
    echo ""
    PANEL_HOST=$(get_host_ip)
    if [[ -z "${PANEL_HOST}" ]]; then
        PANEL_HOST="127.0.0.1"
    fi

    if [ "${INSTALL_CHECK}" == "1" ]; then
        echo "=============== 检测到 1Panel 已经安装, 跳过配置 ==============="
    else
        echo "================ 感谢您的耐心等待, 安装已经完成 ================="
    fi
    echo ""
    echo -e "面板地址:\033[33m http://${PANEL_HOST}:${PANEL_PORT}/${PANEL_ENTRANCE} \033[0m"

    if [ -n "${PANEL_PASSWORD}" ]; then
        echo -e "用户名称:\033[31m $PANEL_USER \033[0m"
        echo -e "用户密码:\033[31m $PANEL_PASSWORD \033[0m"
    fi

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
    check_os
    check_systemd
    check_prepare
    check_docker
    check_compose
    check_1pctl
    check_1panel
    post_install
}

main
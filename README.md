# 1Panel-installer

1Panel 离线安装包, 供无法访问外网的用户使用

## 食用方法

下载对应版本的离线安装包, 解压后运行 `install.sh` 或者 `upgrade.sh` 即可安装或者升级


### 参数说明

./install.sh --help

```bash
Usage: ./install.sh [OPTIONS]

Global Options:
  -h, --help  	 Show this help message and exit
  -v, --version  Show the version information
  --port  	     Configure web access port in the Installation Phase.
  --user  	     Configure 1Panel user in the Installation Phase.
  --password  	 Configure 1Panel password in the Installation Phase.
  --entrance  	 Configure 1Panel web security access in the Installation Phase.
  --install-dir  Configure 1Panel install directory in the Installation Phase.

For more help on how to use Docker, head to https://1panel.cn/docs/

```

### 安装

```bash
## 后台的相关设置, 自行修改
# (*) 密码推荐使用 24 位以上的随机字符串
# (*) 入口推荐使用随机字符串, 比如 --entrance x8elulqXDVTszo6o4j 注意不支持特殊字符串
#
# --port 8888               # 端口号 8888
# --user admin              # 用户名, 通常不要使用 admin 作为用户名
# --password WeakPassword   # 密码, 请使用强密码
# --entrance secret         # 设置 entrance 后只能通过访问 http://ip:port/secret 访问 1Panel
# --install-dir /opt/1panel # 1Panel 数据存储目录

./install.sh --port 8888 --user admin --password WeakPassword --entrance secret --install-dir /opt/1panel
```

### 升级

升级没有参数, 直接执行即可.

```bash
./upgrade.sh
```

### 卸载

```bash
1panel uninstall
```
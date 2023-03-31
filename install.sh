#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

echo "YESSSSS\n"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error：${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red} Failed to check system arch, will use default arch: ${arch}${plain}"
fi

echo "arch: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "x-ui dosen't support 32-bit(x86) system, please use 64 bit operating system(x86_64) instead, if there is something wrong, please get in touch with me!"
    exit -1
fi

os_version=""
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

if [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 7 ]]; then
        echo -e "${red} Please use CentOS 7 or higher ${plain}\n" && exit 1
    fi
elif [[ "${release}" ==  "ubuntu" ]]; then
    if [[ ${os_version} -lt 18 ]]; then
        echo -e "${red}please use Ubuntu 18 or higher version！${plain}\n" && exit 1
    fi

elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red}please use Fedora 36 or higher version！${plain}\n" && exit 1
    fi

elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} Please use Debian 8 or higher ${plain}\n" && exit 1
    fi
else
    echo -e "${red}Failed to check the OS version, please contact the author!${plain}" && exit 1
fi


install_base() {
    if [[ "${release}" == "centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}Install/update finished! For security it's recommended to modify panel settings ${plain}"
    read -p "Do you want to continue with the modification [y/n]? ": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set up your username:" config_account
        echo -e "${yellow}Your username will be:${config_account}${plain}"
        read -p "Please set up your password:" config_password
        echo -e "${yellow}Your password will be:${config_password}${plain}"
        read -p "Please set up the panel port:" config_port
        echo -e "${yellow}Your panel port is:${config_port}${plain}"
        echo -e "${yellow}Initializing, please wait...${plain}"
        /usr/local/x-ui2/x-ui2 setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Account name and password set successfully!${plain}"
        /usr/local/x-ui2/x-ui2 setting -port ${config_port}
        echo -e "${yellow}Panel port set successfully!${plain}"
    else
        echo -e "${red}Canceled, will use the default settings.${plain}"
    fi
}

install_x-ui2() {
    systemctl stop x-ui2
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/alireza0/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it maybe due to Github API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "Got x-ui latest version: ${last_version}, beginning the installation..."
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/alireza0/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Dowanloading x-ui failed, please be sure that your server can access Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/alireza0/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Begining to install x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}dowanload x-ui v$1 failed,please check the verison exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui2/ ]]; then
        rm /usr/local/x-ui2/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui2
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui2 https://github.com/flightlover/x-ui2/blob/main/x-ui2.sh
    chmod +x /usr/local/x-ui2/x-ui2.sh
    chmod +x /usr/bin/x-ui2
    config_after_install
    #echo -e "If it is a new installation, the default web port is ${green}54321${plain}, The username and password are ${green}admin${plain} by default"
    #echo -e "Please make sure that this port is not occupied by other procedures,${yellow} And make sure that port 54321 has been released${plain}"
    #    echo -e "If you want to modify the 54321 to other ports and enter the x-ui command to modify it, you must also ensure that the port you modify is also released"
    #echo -e ""
    #echo -e "If it is updated panel, access the panel in your previous way"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui2
    systemctl start x-ui2
    echo -e "${green}x-ui2 v${last_version}${plain} installation finished, it is up and running now..."
    echo -e ""
    echo -e "x-ui2 control menu usages: "
    echo -e "----------------------------------------------"
    echo -e "x-ui2              - Enter     Admin menu"
    echo -e "x-ui2 start        - Start     x-ui2"
    echo -e "x-ui2 stop         - Stop      x-ui2"
    echo -e "x-ui2 restart      - Restart   x-ui2"
    echo -e "x-ui2 status       - Show      x-ui2 status"
    echo -e "x-ui2 enable       - Enable    x-ui2 on system startup"
    echo -e "x-ui2 disable      - Disable   x-ui2 on system startup"
    echo -e "x-ui2 log          - Check     x-ui2 logs"
    echo -e "x-ui2 v2-ui        - Migrate   v2-ui Account data to x-ui2"
    echo -e "x-ui2 update       - Update    x-ui2"
    echo -e "x-ui2 install      - Install   x-ui2"
    echo -e "x-ui2 uninstall    - Uninstall x-ui2"
    echo -e "----------------------------------------------"
}

echo -e "${green}Excuting...${plain}"
install_base
install_x-ui2 $1

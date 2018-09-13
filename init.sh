#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

clear
echo
echo "#############################################################"
echo "# One click Install Mount & Blade Warband Server in Linux   #"
echo "# Author: Ernest E <ee@cnclub.asia>                         #"
echo "# Github: https://github.com/2er7/warband-bash              #"
echo "#############################################################"
echo

# Current folder
cur_dir=`pwd`
# Battle Mode
mode=(
Battle
Capture_the_Flag
Conquest
Deathmatch
Duel
Figth_and_Destroy
Invasion
Siege
Team_Deathmatch
)
# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

#Check system
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

pre_install(){
    if ! check_sys packageManager apt; then
        echo -e "[${red}Error${plain}] Your OS is not supported. please change OS to Debian or Ubuntu and try again."
        exit 1
    fi

    # Set Warband server name
    echo "Please enter your server name for Warband"
    read -p "(Default server name: SP_Server):" servername
    [ -z "${servername}" ] && servername="SP_Server"
    echo
    echo "---------------------------"
    echo "server name = ${servername}"
    echo "---------------------------"
    echo

    # Set Warband server admin password
    dadminpass=$(openssl rand -hex 4)
    echo "Please enter your Warband server admin passowrd"
    read -p "(Default server admin password: ${dadminpass})" adminpass
    [ -z "${adminpass}"] && adminpass=${dadminpass}
    echo
    echo "---------------------------"
    echo "admin password = ${adminpass}"
    echo "---------------------------"
    echo

    # Set Warband server port
    while true
    do
    dport=$(shuf -i 7140-19999 -n 1)
    echo "Please enter a port for Warband [1-65535]"
    read -p "(Default port: ${dport}):" warbandprot
    [ -z "$warbandprot" ] && warbandprot=${dport}
    expr ${warbandprot} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${warbandprot} -ge 1 ] && [ ${warbandprot} -le 65535 ] && [ ${warbandprot:0:1} != 0 ]; then
            echo
            echo "---------------------------"
            echo "port = ${warbandprot}"
            echo "---------------------------"
            echo
            break
        fi
    fi
    echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
    done

    # Set Warband server battler mode
    while true
    do
    echo -e "Please select Warband server battle mode:"
    for ((i=1;i<=${#mode[@]};i++ )); do
        hint="${mode[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which cipher you'd select(Default: ${mode[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Please enter a number"
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#mode[@]} ]]; then
        echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#mode[@]}"
        continue
    fi
    battlemode=${mode[$pick-1]}
    echo
    echo "---------------------------"
    echo "battle mode = ${battlemode}"
    echo "---------------------------"
    echo
    break
    done

    echo
    echo "Press any key to start...or Press Ctrl+C to cancel"
    char=`get_char`

    # Install necessary dependencies
    
    wget -qO- https://dl.winehq.org/wine-builds/Release.key | sudo apt-key add -
    apt-add-repository https://dl.winehq.org/wine-builds/ubuntu/
    dpkg --add-architecture i386
    apt-get -y update
    apt-get -y install --no-install-recommends openssl curl wget unzip screen dos2unix git
    apt-get -y install --install-recommends winehq-stable 
    cd ${cur_dir}
}

# Download files
download_files(){
    # Download Warband Dedicated
    if ! git clone https://github.com/Fmods/Dedicated.git --recursive; then
        echo -e "[${red}Error${plain}] Failed to download Warband Dedicated!"
        exit 1
    fi
}

# Warband Server Config
config_warband(){
    cd Dedicated
    if ! wget --no-check-certificate https://api.warband.test/config?password_admin=${adminpass}&server_name=${servername}&mission=${battlemode}&port=${warbandprot}&mod=Native; then
        echo -e "[${red}Error${plain}] Failed to download Warband server config file!"
        exit 1
    fi
}

# Install Warband Dedicated
install(){
    # Install Dedicated
    cd ${cur_dir}
    
    clear
    echo
    echo -e "Congratulations, your Warband server install completed!"
    echo -e "Your Server Name           : \033[41;37m ${servername} \033[0m"
    echo -e "Your Server Admin Password : \033[41;37m ${adminpass} \033[0m"
    echo -e "Your Server Port           : \033[41;37m ${warbandprot} \033[0m"
    echo -e "Your Server Battle Mode    : \033[41;37m ${battlemode} \033[0m"
    echo
    echo "Welcome to visit:https://teddysun.com/342.html"
    echo "Enjoy it!"
    echo
}

# Install cleanup
install_cleanup(){
    cd ${cur_dir}
    rm -rf /var/lib/apt/lists/* 
}

# Uninstall Warband Dedicated
uninstall_dedicated(){
    printf "Are you sure uninstall Warband Dedicated? (y/n) "
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        apt-get remove -y winehq-stable
        # delete Warband Dedicated
        rm -rf ./Dedicated
        echo "Warband Dedicated uninstall success!"
    else
        echo
        echo "uninstall cancelled, nothing to do..."
        echo
    fi
}

install_dedicated(){
    disable_selinux
    pre_install
    download_files
    config_warband
    install
    install_cleanup
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_dedicated
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: `basename $0` [install|uninstall]"
    ;;
esac
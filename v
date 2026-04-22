#!/bin/bash

declare -r COMMAND_NAME="$(basename "$0")"

declare IsVPN=true

function getEnv(){
    local envName="$1"
    if [[ -z "$envName" ]];then
        echo ""
        return 0
    fi
    envVal="${!envName}"
    if [[ -z "$envVal" ]];then
        local bashName=$(basename "$SHELL")
        if [[ "$bashName" == "bash" ]] && [[ -f ~/.bashrc ]] ;then
            envVal=$(grep "$envName" ~/.bashrc | tail -n1 | awk -F'[ =]+' '{print $NF}')
        fi
        if [[ "$bashName" == "zsh" ]] && [[ -f ~/.zshrc ]];then
            envVal=$(grep "$envName" ~/.zshrc | tail -n1 | awk -F'[ =]+' '{print $NF}')
        fi
    fi
    echo "$envVal"
    return 0
}

function setEnvIfEmpty(){
    local envName="$1"
    local envVal="$2"
    if [[ -z "$envName" ]] || [[ -z "$envVal" ]];then
        return 0
    fi
    if [[ -n "$(getEnv "$envName")" ]];then
        return 0
    fi
    local bashName=$(basename "$SHELL")
    local bashPath=""
    if [[ "$bashName" == "bash" ]];then
        bashPath="$HOME/.bashrc"
    elif [[ "$bashName" == "zsh" ]];then
        bashPath="$HOME/.zshrc"
    fi
    echo "export $envName=$envVal" >> "$bashPath"
}

declare -r VPN_LIST=(
    "/opt/cisco/anyconnect/bin/vpn:ciscoAnyconnectVPN_func"
    # "openvpnLogin:openvpn_func"
)
declare -r VPN_STSTUS_ON="on"
declare -r VPN_STSTUS_OFF="off"
declare VpnCurrentStatus=false
declare VpnCurrentAppIsOpen=false

function ciscoAnyconnectVPN_func() {
    local envName="CISCO_ANYCONNECT_VPN_ADDRESS"
    local vpnAppName="Cisco AnyConnect Secure Mobility Client"
    local vpnFuncPath="$1"
    local vpnStatus="$2"
    if ! $(command -v "$vpnFuncPath" > /dev/null 2>&1);then
        echo >&2 "命令未找到：$vpnFuncPath"
        return 1
    fi
    if [[ "$vpnStatus" != "$VPN_STSTUS_ON" ]] && [[ "$vpnStatus" != "$VPN_STSTUS_OFF" ]];then
        echo >&2 "状态错误：请输入VPN状态：on/off"
        return 2
    fi
    local errorCountNum=0
    vpnAddress="$(getEnv "$envName")"
    if [[ "$vpnAddress" == "" ]];then
        while read -p "请输入VPN连接的服务器地址:" -r vpnServerAddress ;do
            if [[ "$vpnServerAddress" != "" ]];then
                vpnAddress="$vpnServerAddress"
                break
            fi
            ((errorCountNum++))
            if ((errorCountNum >= 3));then
                echo >&2 "输入错误次数过多，退出"
                return 1
            fi
        done
    fi
    local actionCmd="connect"
    if [[ "$vpnStatus" == "$VPN_STSTUS_OFF" ]];then
        actionCmd="disconnect"
    fi
    currentBranchNameTemp=$(git_current_branch) || {
        return 1
    }

    if [[ "$vpnStatus" == "$VPN_STSTUS_ON" ]];then
        local vpnStatusMsg=$($vpnFuncPath stats|grep 'Connection State' |grep -v Management|awk -F'[: ]+' '{print $NF}')
        if [[ "$vpnStatusMsg" == "Connected" ]];then
            VpnCurrentStatus=true
            printFormat "VPN 已连接，无需重复连接"
            return 0
        fi
        if [[ "$vpnStatusMsg" == "Disconnected" ]];then
            ps -ef | grep "$vpnAppName" | grep -v 'grep' > /dev/null 2>&1 && {
                pkill -f "$vpnAppName" && {
                    printFormat "VPN 软件已打开但是未链接，尝试关闭图形客户端"
                    VpnCurrentAppIsOpen=true
                }
            }
        fi
    elif ${VpnCurrentStatus} && [[ "$vpnStatus" == "$VPN_STSTUS_OFF" ]];then
        printFormat "VPN 原本就是已连接状态，无需执行断开连接操作"
        return 0
    fi

    printFormat "${vpnFuncPath} ${actionCmd} ${vpnAddress}"
    $vpnFuncPath "$actionCmd" "$vpnAddress" > /dev/null 2>&1 || {
        echo >&2 "执行VPN命令失败：$vpnFuncPath $actionCmd $vpnAddress"
        return 1
    }
    # if [[ "$vpnStatus" == "$VPN_STSTUS_ON" ]];then
    #     local vpnStatusMsg=$($vpnFuncPath stats|grep 'Connection State' |grep -v Management|awk -F'[: ]+' '{print $NF}')
    #     if [[ "$vpnStatusMsg" == "Connected" ]];then
    #         printFormat "VPN 已连接"
    #     fi
    # fi

    if ${VpnCurrentAppIsOpen} && [[ "$vpnStatus" == "$VPN_STSTUS_OFF" ]];then
        printFormat "VPN 尝试打开图形客户端软件"
        open -a "$vpnAppName"
    fi

    if [[ "${!envName}" == "" ]];then
        local vpnStatusMsg=$($vpnFuncPath stats|grep 'Connection State' |grep -v Management|awk -F'[: ]+' '{print $NF}')
        if [[ "$vpnStatusMsg" == "Connected" ]];then
            setEnvIfEmpty "$envName" "$vpnAddress"
        fi
    fi
}

function openvpn_func() {
    echo ""
}

function useVPN() {
    if ! $IsVPN ;then
        return 0
    fi
    local vpnStatus="$1"
    if [[ "$vpnStatus" != "$VPN_STSTUS_ON" ]] && [[ "$vpnStatus" != "$VPN_STSTUS_OFF" ]];then
        echo >&2 "状态错误：请输入VPN状态：on/off"
        return 2
    fi
    local availableVpnList=()
    for v in ${VPN_LIST[@]};do
        cmdStr="${v%:*}"
        if command -v "$cmdStr" > /dev/null 2>&1;then
            availableVpnList+=("$cmdStr")
        fi
    done
    local vpnFuncInfo=""
    if [[ "${#availableVpnList[@]}" == "1" ]];then
        vpnFuncInfo="${VPN_LIST[0]}"
    else
        local k=0
        for val in ${availableVpnList[@]} ;do
            ((k++))
            printf " %s\t%s\n" "$k" "$val"
        done
        local errorCountNum=0
        while read -p "请选择VPN连接（输入序号[1-${#availableVpnList[@]}]）:" -r vpnIndex ;do
            if [[ "${vpnIndex}" =~ ^[1-9]+$ ]];then
                vpnFuncInfo="${VPN_LIST[$vpnIndex-1]}"
                if [[ "$vpnFuncInfo" != "" ]];then
                    break
                fi
            fi
            ((errorCountNum++))
            if ((errorCountNum >= 3));then
                echo >&2 "输入错误次数过多，退出"
                return 1
            fi
        done
    fi
    local vpnFuncName="${vpnFuncInfo#*:}"
    local vpnFuncPath="${vpnFuncInfo%:*}"
    $vpnFuncName "$vpnFuncPath" "$vpnStatus"
}

function printFormat(){
    local data="$@"
    local currentBranchNameTemp
    currentBranchNameTemp=$(git_current_branch) || {
        return 1
    }
    local commandPrefix="\033[32m[$(date '+%F %T')] \033[36m$DIR_NAME\033[32m (\033[31;1m$currentBranchNameTemp\033[0;32m)\033[1m ➜ \033[0m"
    echo -e "${commandPrefix}\033[33m$data\033[0m"
}

function git_current_branch() {
  local ref
  ref=$(git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && {
        return 21 # no git repo.
    }
    ref=$(git rev-parse --short HEAD 2> /dev/null) || {
        return 22
    }
  fi
  echo ${ref#refs/heads/}
}

function main(){
    useVPN "$VPN_STSTUS_ON"
    printFormat "${@}"
    "${@}"
    local retCode=$?
    useVPN "$VPN_STSTUS_OFF"
    return $retCode
}

main "$@"

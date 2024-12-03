#!/bin/bash

commandName="${0##*/}"

isNoCheckout=false
while getopts "n:" opt;do
    case "$opt" in
        n)
            isNoCheckout=true
        ;;
    esac
done

echo "$isNoCheckout"
exit 1



if [[ "$1" == "-h" || "$1" == "--help" ]];then
    cat <<!
        command:$commandName
        说明：
            会把git的"当前分支"合并到"${commandName}"开发分支
            如果想变更要合并的开发分支，修改脚本名称即可
!
    exit 0
fi

readonly developmentBranch="$commandName"

commitInfo="$1"
if [[ "$commitInfo" == "" ]];then
    echo "input commit info"
    exit 1
fi

function getCurrentBranchName(){
    local branchList
    local grepList
    local currentBranchName
    branchList=$(git branch) || {
        return 11
    }
    grepList=$(echo "$branchList" | grep "*") || {
        echo "grep no find branch" >&2
        return 12
    }
    currentBranchName=$(echo "$grepList" | awk '{print $2}')
    if [[ "$currentBranchName" == "" ]] ;then
        echo "awk no find branch name" >&2
        return 13
    fi
    echo "$currentBranchName"
    return 0
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
    local dirName="$(pwd)"
    dirName=${dirName##*/}
    local currentBranchName
    currentBranchName=$(git_current_branch) || {
        local tempCode="$?"
        if [[ "$tempCode" == "21" ]];then
            echo "not a git repository"
        fi
        return $tempCode
    }
    if [[ "$currentBranchName" == "$developmentBranch" ]];then
        echo "current is target development branch"
        return 1
    fi
    execList=(
        "git --no-pager diff"
        "git add -A"
        "git commit -m '$commitInfo'"
        "git pull"
        "git push"
        "git checkout $developmentBranch"
        "git pull"
        "git merge $currentBranchName -m 'Merge branch $currentBranchName into $developmentBranch'"
        "git push"
        "git --no-pager log --no-color -n 1"
        "git checkout $currentBranchName"
    );
    local implemented
    for commandStr in "${execList[@]}" ;do
        if [[ "$implemented" == "$commandStr" ]];then
            continue
        fi
        implemented="$commandStr"
        dateTime=$(date '+%F %T')
        currentBranchNameTemp=$(git_current_branch) || {
            return 1
        }
        commandPrefix="\033[32m[$dateTime] \033[36m$dirName\033[32m (\033[31;1m$currentBranchNameTemp\033[0;32m)\033[1m ➜ \033[0m"
        echo  -e "${commandPrefix}\033[33m${commandStr}\033[0m"
        eval "$commandStr" || {
            echo ""
            echo -e "Execution Failed"
            echo -e "   Solution:"
            echo -e "       • p: Push Again    "
            echo -e "       • s: Skip          "
            echo -e "       • e: Exit          "
            str=$(echo -e  "\033[31;1mSelect Execution(y/n or s):\033[0m")
            while read -p "$str" -r row ;do
                if [[ "$row" == "e" || "$row" == "E" ]];then
                    return 1
                elif [[ "$row" == "s" || "$row" == "S" ]];then
                    break
                elif [[ "$row" == "p" || "$row" == "P" ]];then
                    conflictExecList=(
                        "git add -A"
                        "git commit -m 'resolve the conflict：$commitInfo'"
                        "git pull"
                        "git push"
                    )
                    for val in "${conflictExecList[@]}" ;do
                        dateTime=$(date '+%F %T')
                        implemented="$val"
                        echo  -e "${commandPrefix}\033[33m${val}\033[0m"
                        eval "$val" || {
                            return 1
                        }
                    done
                    break
                else
                    continue
                fi
            done
        }
    done
}

main



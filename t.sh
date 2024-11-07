#!/bin/bash

isHelp=false
isVersion=false
username=""
passwd=""

OPTIND=1
while getopts "u:p:-:hv" opt;do
    case "$opt" in
        h)
            isHelp=true;;
        v)
            isVersion=true;;
        u)
            username="$OPTARG";;
        p)
            passwd="$OPTARG";;
        -)
            longArgKey="${OPTARG%%=*}"
            longArgVal="${OPTARG#*=}"
            if [[ "$longArgKey" == "$OPTARG" ]];then
                # bool values
                case "$longArgKey" in
                    help)
                        isHelp=true;;
                    version)
                        isVersion=true;;
                esac
                continue
            fi
            case "$longArgKey" in
                username)
                    username="$longArgVal";;
                passwd)
                    passwd="$longArgVal";;
            esac
            ;;
        *)
            ;;
    esac
done
shift $(($OPTIND-1))

echo "help:$isHelp;version:$isVersion;username:$username;passwd:$passwd"


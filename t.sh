#!/bin/bash  
  
# 定义要处理的选项和长选项  
OPTIONS=hv  
LONGOPTIONS=help,version,xxxx  
  
# 使用 getopt 解析参数  
PARSED=$(getopt --options $OPTIONS --longoptions $LONGOPTIONS --name "$0" -- "$@")  
if [ $? -ne 0 ]; then  
    echo "Usage: $0 --help" >&2  
    exit 1  
fi  
  
# eval 将解析后的参数重新赋值给位置参数  
eval set -- "$PARSED"  
  
# 初始化变量  
VERSION="1.0.0"  
  
# 处理每个参数  
while true; do  
    case "$1" in  
        -h|--help)  
            echo "Usage: $0 [--help] [--version] [--xxxx]"  
            exit 0  
            ;;  
        -v|--version)  
            echo "Version $VERSION"  
            exit 0  
            ;;  
        --xxxx)  
            echo "Option --xxxx was selected"  
            # 在这里添加 --xxxx 选项的处理逻辑  
            ;;  
        --)  
            shift  
            break  
            ;;  
        *)  
            echo "Usage: $0 [--help] [--version] [--xxxx]" >&2  
            exit 1  
            ;;  
    esac  
    shift  
done  
  
# 主脚本逻辑（如果没有选择帮助或版本选项）  
echo "Script is running with arguments: $@"  
# 在这里添加你的脚本逻辑

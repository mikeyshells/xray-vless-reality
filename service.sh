#!/usr/bin/env bash

red='\e[91m'
green='\e[92m'
yellow='\e[93m'
cyan='\e[96m'
none='\e[0m'

XRAY_SERVICE="xray"

error() {
    echo -e "\n$red 输入错误! $none\n"
}

warn() {
    echo -e "\n$yellow $1 $none\n"
}

pause() {
    read -rsp "$(echo -e "按 $green Enter 回车键 $none 继续....或按 $red Ctrl + C $none 取消.")" -d $'\n'
    echo
}

check_xray_installed() {
    if ! command -v xray &>/dev/null; then
        warn "未检测到 xray 命令, 请先运行 install.sh 安装 Xray."
        exit 1
    fi

    local has_service=0
    if systemctl list-unit-files 2>/dev/null | grep -q "^${XRAY_SERVICE}\.service"; then
        has_service=1
    elif [[ -f /etc/systemd/system/${XRAY_SERVICE}.service || -f /usr/lib/systemd/system/${XRAY_SERVICE}.service ]]; then
        has_service=1
    elif command -v service &>/dev/null && [[ -f /etc/init.d/${XRAY_SERVICE} ]]; then
        has_service=1
    fi

    if [[ $has_service -eq 0 ]]; then
        warn "未检测到 ${XRAY_SERVICE} 系统服务, 请先运行 install.sh 安装 Xray."
        exit 1
    fi
}

run_service() {
    local action=$1
    echo
    echo -e "$yellow${action} Xray 服务$none"
    echo "----------------------------------------------------------------"
    if systemctl list-unit-files 2>/dev/null | grep -q "^${XRAY_SERVICE}\.service" \
        || [[ -f /etc/systemd/system/${XRAY_SERVICE}.service || -f /usr/lib/systemd/system/${XRAY_SERVICE}.service ]]; then
        systemctl "$action" "$XRAY_SERVICE"
    else
        service "$XRAY_SERVICE" "$action"
    fi
    local ret=$?
    echo
    if [[ $ret -eq 0 ]]; then
        echo -e "$green 操作成功.$none"
    else
        echo -e "$red 操作失败, 请检查是否以 root 权限运行.$none"
    fi
    echo "----------------------------------------------------------------"
}

show_status() {
    echo
    echo -e "$yellow Xray 服务状态 $none"
    echo "----------------------------------------------------------------"
    if systemctl list-unit-files 2>/dev/null | grep -q "^${XRAY_SERVICE}\.service"; then
        systemctl status "$XRAY_SERVICE" --no-pager -l
    else
        service "$XRAY_SERVICE" status
    fi
    echo "----------------------------------------------------------------"

    if [[ -f /usr/local/etc/xray/config.json ]]; then
        echo
        echo -e "$yellow 配置文件: ${cyan}/usr/local/etc/xray/config.json$none"
    fi
    if [[ -f /var/log/xray/error.log ]]; then
        echo -e "$yellow 错误日志: ${cyan}/var/log/xray/error.log$none"
    fi
    if [[ -f /var/log/xray/access.log ]]; then
        echo -e "$yellow 访问日志: ${cyan}/var/log/xray/access.log$none"
    fi
    if [[ -f ~/_vless_reality_url_ ]]; then
        echo -e "$yellow 节点信息: ${cyan}~/_vless_reality_url_$none"
    fi
}

show_log_menu() {
    echo
    echo -e "$cyan========== 查看实时日志 ==========$none"
    echo -e "  ${green}1$none) 错误日志  ${cyan}/var/log/xray/error.log$none"
    echo -e "  ${green}2$none) 访问日志  ${cyan}/var/log/xray/access.log$none"
    echo -e "  ${green}3$none) 系统日志  ${cyan}journalctl -u xray$none"
    echo -e "  ${green}0$none) 返回主菜单"
    echo "----------------------------------------------------------------"
}

tail_log_file() {
    local log_file=$1
    local log_name=$2

    if [[ ! -f "$log_file" ]]; then
        warn "日志文件不存在: $log_file"
        return 1
    fi

    echo
    echo -e "$yellow 正在跟踪 ${log_name} 日志, 按 ${red}Ctrl + C$none 停止并返回菜单 $none"
    echo "----------------------------------------------------------------"
    trap 'echo; echo -e "\n$yellow 已停止查看日志.$none"; trap - INT; return 0' INT
    tail -n 50 -f "$log_file"
    trap - INT
}

tail_journal() {
    if ! command -v journalctl &>/dev/null; then
        warn "当前系统不支持 journalctl."
        return 1
    fi

    echo
    echo -e "$yellow 正在跟踪 Xray 系统日志, 按 ${red}Ctrl + C$none 停止并返回菜单 $none"
    echo "----------------------------------------------------------------"
    trap 'echo; echo -e "\n$yellow 已停止查看日志.$none"; trap - INT; return 0' INT
    journalctl -u "$XRAY_SERVICE" -f --no-pager -n 50
    trap - INT
}

show_logs() {
    while true; do
        show_log_menu
        read -p "$(echo -e "请选择日志类型 [0-3]: ")" log_choice
        case "$log_choice" in
        1)
            tail_log_file "/var/log/xray/error.log" "错误"
            ;;
        2)
            tail_log_file "/var/log/xray/access.log" "访问"
            ;;
        3)
            tail_journal
            ;;
        0)
            return 0
            ;;
        *)
            error
            ;;
        esac
    done
}

show_menu() {
    echo
    echo -e "$cyan========== Xray 服务管理 ==========$none"
    echo -e "  ${green}1$none) 启动服务"
    echo -e "  ${green}2$none) 关闭服务"
    echo -e "  ${green}3$none) 重启服务"
    echo -e "  ${green}4$none) 显示服务状态"
    echo -e "  ${green}5$none) 查看实时日志"
    echo -e "  ${green}0$none) 退出"
    echo "----------------------------------------------------------------"
}

main() {
    if [[ $EUID -ne 0 ]]; then
        warn "请使用 root 权限运行此脚本, 例如: sudo bash control.sh"
        exit 1
    fi

    check_xray_installed

    while true; do
        show_menu
        read -p "$(echo -e "请输入序号 [0-5]: ")" choice
        case "$choice" in
        1)
            run_service start
            pause
            ;;
        2)
            run_service stop
            pause
            ;;
        3)
            run_service restart
            pause
            ;;
        4)
            show_status
            pause
            ;;
        5)
            show_logs
            ;;
        0)
            echo
            echo -e "$green 已退出.$none"
            exit 0
            ;;
        *)
            error
            ;;
        esac
    done
}

main "$@"

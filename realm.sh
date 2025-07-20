#!/bin/bash
#====================================================
#       System  : CentOS 7+ / Debian 8+ / Ubuntu 16+
#       Author  : j2st1n
#       Script  : Realm All-in-One Manager
#       Version : 1.3.7
#====================================================

# ---------- 颜色 ----------
GREEN="\033[32m"; RED="\033[31m"
YELLOW="\033[33m"; BLUE="\033[34m"; CYAN="\033[36m"; ENDCOLOR="\033[0m"

# ---------- 目录 ----------
REALM_BIN_PATH="/usr/local/bin/realm"
REALM_CONFIG_DIR="/etc/realm"
REALM_CONFIG_PATH="${REALM_CONFIG_DIR}/config.toml"
REALM_SERVICE_PATH="/etc/systemd/system/realm.service"
LOG_PATH="/var/log/realm.log"

# ---------- 下载镜像 ----------
ASSET="realm-x86_64-unknown-linux-gnu.tar.gz"
MIRRORS=(
  "https://mirror.ghproxy.com/https://github.com/zhboner/realm/releases/latest/download/${ASSET}"
  "https://ghproxy.com/https://github.com/zhboner/realm/releases/latest/download/${ASSET}"
  "https://download.fastgit.org/zhboner/realm/releases/latest/download/${ASSET}"
  "https://gcore.jsdelivr.net/gh/zhboner/realm@latest/${ASSET}"
  "https://github.com/zhboner/realm/releases/latest/download/${ASSET}"
)

# ---------- 防火墙类型 ----------
FIREWALL_TYPE="" # firewalld/ufw/none

# ---------- 权限检查 ----------
[[ $EUID -eq 0 ]] || { echo -e "${RED}必须以 root 运行！${ENDCOLOR}"; exit 1; }

# ---------- 安装检测 ----------
check_install() { [[ -f $REALM_BIN_PATH ]]; }

# ---------- 分隔线 ----------
div() { echo "------------------------------------------------------------"; }

# ---------- 检测防火墙 ----------
detect_firewall() {
  if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
    FIREWALL_TYPE="firewalld"
  elif command -v ufw &>/dev/null && ufw status | grep -q active; then
    FIREWALL_TYPE="ufw"
  else
    FIREWALL_TYPE="none"
  fi
}

# ---------- 防火墙管理 ----------
manage_firewall() {
  local action=$1 port=$2
  
  case $FIREWALL_TYPE in
    firewalld)
      case $action in
        open)
          firewall-cmd --add-port=${port}/tcp >/dev/null 2>&1
          firewall-cmd --permanent --add-port=${port}/tcp >/dev/null 2>&1
          ;;
        close)
          firewall-cmd --remove-port=${port}/tcp >/dev/null 2>&1
          firewall-cmd --permanent --remove-port=${port}/tcp >/dev/null 2>&1
          ;;
      esac
      ;;
    ufw)
      case $action in
        open) ufw allow ${port}/tcp >/dev/null 2>&1 ;;
        close) ufw delete allow ${port}/tcp >/dev/null 2>&1 ;;
      esac
      ;;
  esac
}

# ---------- 端口检查 ----------
check_port() {
  local port=$1
  if grep -q "listen = \"0.0.0.0:${port}\"" "$REALM_CONFIG_PATH" || 
     grep -q "listen = \"[^]]*:${port}\"" "$REALM_CONFIG_PATH"; then
    return 1
  fi
  if ss -tuln | grep -q ":${port} "; then
    return 1
  fi
  return 0
}

# ---------- 生成随机端口 ----------
generate_random_port() {
  local attempts=0
  while (( attempts++ < 20 )); do
    local port=$((RANDOM % 50000 + 10000))
    if check_port "$port"; then
      echo "$port"
      return 0
    fi
  done
  echo ""
}

# ---------- 下载函数 ----------
fetch_realm() {
  for url in "${MIRRORS[@]}"; do
    echo -e "${BLUE}尝试下载：${url}${ENDCOLOR}"
    if curl -fsSL "$url" | tar xz; then
      echo -e "${GREEN}下载成功！镜像：${url}${ENDCOLOR}"
      return 0
    else
      echo -e "${YELLOW}镜像不可用，切换下一个…${ENDCOLOR}"
      rm -f "$ASSET" 2>/dev/null
    fi
  done
  echo -e "${RED}全部镜像尝试失败，无法下载 Realm。${ENDCOLOR}"
  return 1
}

# ---------- 安装 ----------
install_realm() {
  if check_install; then
    echo -e "${GREEN}Realm 已安装，无需重复操作。${ENDCOLOR}"
    return
  fi

  echo -e "${YELLOW}开始安装 Realm...${ENDCOLOR}"
  div
  fetch_realm || exit 1

  mv realm "$REALM_BIN_PATH" && chmod +x "$REALM_BIN_PATH"

  mkdir -p "$REALM_CONFIG_DIR"
  cat >"$REALM_CONFIG_PATH" <<EOF
[log]
level = "info"
output = "${LOG_PATH}"
EOF

  cat >"$REALM_SERVICE_PATH" <<EOF
[Unit]
Description=Realm Binary Custom Service
After=network.target

[Service]
Type=simple
User=root
Restart=always
ExecStart=${REALM_BIN_PATH} -c ${REALM_CONFIG_PATH}
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable realm >/dev/null 2>&1

  detect_firewall
  
  div
  echo -e "${GREEN}Realm 安装成功！${ENDCOLOR}"
  echo -e "${YELLOW}已设置开机自启，但尚未启动，请先添加转发规则。${ENDCOLOR}"
  [[ $FIREWALL_TYPE != "none" ]] && \
    echo -e "${CYAN}检测到防火墙: ${FIREWALL_TYPE}，添加规则时将自动放行端口${ENDCOLOR}"
}

# ---------- 添加转发规则 ----------
add_rule() {
  check_install || { echo -e "${RED}请先安装 Realm。${ENDCOLOR}"; return; }

  echo -e "${YELLOW}添加转发规则 (支持域名/IPv4/IPv6)${ENDCOLOR}"
  while true; do
    read -p "本地监听端口(默认则随机）: " listen_port
    
    if [[ -z "$listen_port" ]]; then
      listen_port=$(generate_random_port)
      [[ -n "$listen_port" ]] && break
      echo -e "${RED}无法生成可用端口，请手动指定${ENDCOLOR}"
    fi
    
    if ! [[ $listen_port =~ ^[0-9]+$ ]]; then
      echo -e "${RED}端口必须是数字${ENDCOLOR}"
      continue
    fi
    
    if (( listen_port < 1 || listen_port > 65535 )); then
      echo -e "${RED}端口范围 1-65535${ENDCOLOR}"
      continue
    fi
    
    if ! check_port "$listen_port"; then
      echo -e "${RED}端口 ${listen_port} 已被使用${ENDCOLOR}"
      continue
    fi
    
    break
  done

  read -p "远程目标地址: " remote_addr
  read -p "远程目标端口: " remote_port

  if ! [[ $remote_port =~ ^[0-9]+$ ]] || (( remote_port < 1 || remote_port > 65535 )); then
    echo -e "${RED}目标端口无效${ENDCOLOR}"; return
  fi

  if [[ $remote_addr == *":"* ]] && [[ $remote_addr != "["*"]" ]]; then
    remote_addr="[${remote_addr}]"
  fi

  detect_firewall
  if [[ $FIREWALL_TYPE != "none" ]]; then
    manage_firewall open "$listen_port"
    echo -e "${CYAN}已在防火墙放行端口: ${listen_port}${ENDCOLOR}"
  fi

  cat >>"$REALM_CONFIG_PATH" <<EOF

[[endpoints]]
listen = "0.0.0.0:$listen_port"
remote = "$remote_addr:$remote_port"
EOF

  systemctl reload realm >/dev/null 2>&1

  div
  echo -e "${GREEN}规则添加成功！${ENDCOLOR}"
  echo -e "监听端口: ${YELLOW}$listen_port${ENDCOLOR} -> 目标地址: ${YELLOW}$remote_addr:$remote_port${ENDCOLOR}"
}

# ---------- 删除转发规则 (带序号) ----------
delete_rule() {
  check_install || { echo -e "${RED}请先安装 Realm。${ENDCOLOR}"; return; }
  
  if ! grep -q -E '\[\[endpoints\]\]' "$REALM_CONFIG_PATH"; then
    echo -e "${RED}无转发规则可删除。${ENDCOLOR}"; return
  fi

  mapfile -t start_lines < <(grep -n '\[\[endpoints\]\]' "$REALM_CONFIG_PATH" | cut -d: -f1)
  
  if [ ${#start_lines[@]} -eq 0 ]; then
    echo -e "${RED}无转发规则可删除。${ENDCOLOR}"; return
  fi

  echo -e "${YELLOW}当前转发规则:${ENDCOLOR}"
  div
  for i in "${!start_lines[@]}"; do
    local num=$((i+1))
    local start_line=${start_lines[$i]}
    local listen_line=$(sed -n "$((start_line+1))p" "$REALM_CONFIG_PATH")
    local remote_line=$(sed -n "$((start_line+2))p" "$REALM_CONFIG_PATH")
    
    local listen_port=$(echo "$listen_line" | awk -F'[":]' '{print $4}')
    local remote=$(echo "$remote_line" | awk -F'"' '{print $2}')
    local listen_ip=$(echo "$listen_line" | awk -F'[":]' '{print $3}' | tr -d '"')
    
    printf "  %-4s -> %-20s -> %-30s\n" \
      "$num" "${listen_ip}:${listen_port}" "$remote"
  done
  div

  while true; do
    read -p "请输入要删除的规则序号 (输入0取消): " choice
    [[ $choice == 0 ]] && return
    
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#start_lines[@]} )); then
      local index=$((choice-1))
      local start_line=${start_lines[$index]}
      local end_line=$((start_line + 2))
      
      local listen_line=$(sed -n "$((start_line+1))p" "$REALM_CONFIG_PATH")
      # 使用更健壮的 grep 命令替换掉原来的 awk 命令
      local listen_port=$(echo "$listen_line" | grep -oP ':\K[0-9]+(?=")')
      
      detect_firewall
      if [[ $FIREWALL_TYPE != "none" ]] && [[ -n "$listen_port" ]]; then
        manage_firewall close "$listen_port"
        echo -e "${CYAN}已关闭防火墙端口: $listen_port${ENDCOLOR}"
      fi
      
      sed -i "${start_line},${end_line}d" "$REALM_CONFIG_PATH"
      
      systemctl reload realm >/dev/null 2>&1
      echo -e "${GREEN}规则删除成功！${ENDCOLOR}"
      return
    else
      echo -e "${RED}无效序号，请重新输入${ENDCOLOR}"
    fi
  done
}

# ---------- 显示状态 ----------
status() {
  check_install || { echo -e "${RED}请先安装 Realm。${ENDCOLOR}"; return; }
  
  echo -e "${YELLOW}Realm 服务状态:${ENDCOLOR}"
  div
  systemctl status realm --no-pager -l | head -n 10
  div
  
  mapfile -t start_lines < <(grep -n '\[\[endpoints\]\]' "$REALM_CONFIG_PATH" | cut -d: -f1)
  
  if [ ${#start_lines[@]} -gt 0 ]; then
    echo -e "${YELLOW}当前转发规则:${ENDCOLOR}"
    div
    for i in "${!start_lines[@]}"; do
      local start_line=${start_lines[$i]}
      local listen_line=$(sed -n "$((start_line+1))p" "$REALM_CONFIG_PATH")
      local remote_line=$(sed -n "$((start_line+2))p" "$REALM_CONFIG_PATH")
      
      local listen_port=$(echo "$listen_line" | awk -F'[":]' '{print $4}')
      local remote=$(echo "$remote_line" | awk -F'"' '{print $2}')
      local listen_ip=$(echo "$listen_line" | awk -F'[":]' '{print $3}' | tr -d '"')
      
      local status="[已放行]"
      if [[ $FIREWALL_TYPE == "firewalld" ]]; then
        firewall-cmd --query-port="$listen_port/tcp" >/dev/null 2>&1 || status="[未放行]"
      elif [[ $FIREWALL_TYPE == "ufw" ]]; then
        ufw status | grep -q "$listen_port" || status="[未放行]"
      fi
      
      printf "  %-20s -> %-30s %s\n" "${listen_ip}:${listen_port}" "$remote" "$status"
    done
    div
  else
    echo -e "${RED}无转发规则${ENDCOLOR}"
  fi
}

# ---------- 启动/停止服务 ----------
service_control() {
  check_install || { echo -e "${RED}请先安装 Realm。${ENDCOLOR}"; return; }
  
  case $1 in
    start)
      systemctl start realm
      echo -e "${GREEN}Realm 已启动${ENDCOLOR}"
      ;;
    stop)
      systemctl stop realm
      echo -e "${YELLOW}Realm 已停止${ENDCOLOR}"
      ;;
    restart)
      systemctl restart realm
      echo -e "${CYAN}Realm 已重启${ENDCOLOR}"
      ;;
  esac
}

# ---------- 防火墙状态检查 ----------
check_firewall_ports() {
  detect_firewall
  case $FIREWALL_TYPE in
    firewalld)
      echo -e "${YELLOW}Firewalld 放行端口:${ENDCOLOR}"
      firewall-cmd --list-ports
      ;;
    ufw)
      echo -e "${YELLOW}UFW 放行规则:${ENDCOLOR}"
      ufw status | grep ALLOW
      ;;
    *)
      echo -e "${YELLOW}未检测到活动防火墙${ENDCOLOR}"
      ;;
  esac
}

# ---------- 主菜单 ----------
main_menu() {
  while true; do
    echo -e "\n${BLUE}Realm 管理脚本 v1.3.6${ENDCOLOR}"
    div
    echo "1. 安装/更新 Realm"
    echo "2. 添加转发规则"
    echo "3. 删除转发规则"
    echo "4. 查看当前状态"
    echo "5. 启动服务"
    echo "6. 停止服务"
    echo "7. 重启服务"
    echo "8. 检查防火墙放行端口"
    echo "0. 退出脚本"
    div
    
    read -p "请输入选项: " choice
    case $choice in
      1) install_realm ;;
      2) add_rule ;;
      3) delete_rule ;;
      4) status ;;
      5) service_control start ;;
      6) service_control stop ;;
      7) service_control restart ;;
      8) check_firewall_ports ;;
      0) echo -e "${GREEN}已退出脚本${ENDCOLOR}"; exit 0 ;;
      *) echo -e "${RED}无效选项${ENDCOLOR}" ;;
    esac
  done
}

# ---------- 执行主菜单 ----------
main_menu
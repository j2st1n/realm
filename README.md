# Realm All-in-One Manager

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

一个功能强大的Bash脚本，用于在Linux服务器上轻松管理和配置Realm端口转发服务。支持一键安装、规则管理、防火墙自动配置等功能。

## 🚀 功能特性

- **一键安装/更新**：自动下载最新版Realm并配置为系统服务
- **智能端口转发**：轻松添加/删除转发规则，支持IPv4/IPv6和域名
- **防火墙自动管理**：支持firewalld和ufw，自动放行端口
- **服务状态监控**：实时查看Realm服务状态和转发规则
- **随机端口生成**：智能检测可用端口，避免冲突
- **多镜像下载**：多个下载源确保安装成功
- **系统服务集成**：自动配置systemd服务，支持开机自启

## ⚙️ 系统要求

- CentOS 7+
- Debian 8+
- Ubuntu 16+
- 需要root权限运行

## 📦 安装方法

1. 下载脚本：
```bash
curl -O https://raw.githubusercontent.com/j2st1n/realm/refs/heads/main/realm.sh
```

2. 添加执行权限：
```bash
chmod +x realm.sh
```

3. 运行脚本：
```bash
sudo ./realm.sh
```

## 🖥 使用说明

运行脚本后，您将看到以下主菜单：

```
Realm 管理脚本 v1.3.6
------------------------------------------------------------
1. 安装/更新 Realm
2. 添加转发规则
3. 删除转发规则
4. 查看当前状态
5. 启动服务
6. 停止服务
7. 重启服务
8. 检查防火墙放行端口
0. 退出脚本
------------------------------------------------------------
```

### 常用操作示例

**添加转发规则：**
```
1. 选择"2. 添加转发规则"
2. 输入本地监听端口（留空则自动生成随机端口）
3. 输入远程目标地址（IP/域名/IPv6地址）
4. 输入远程目标端口
```

**查看当前状态：**
```
1. 选择"4. 查看当前状态"
2. 查看服务运行状态和所有转发规则
3. 查看防火墙端口放行状态
```

**管理服务：**
- 启动服务：选项5
- 停止服务：选项6
- 重启服务：选项7

## 🔧 技术细节

### 配置文件路径
- 主程序：`/usr/local/bin/realm`
- 配置文件：`/etc/realm/config.toml`
- 服务文件：`/etc/systemd/system/realm.service`
- 日志文件：`/var/log/realm.log`

### 配置文件示例
```toml
[log]
level = "info"
output = "/var/log/realm.log"

[[endpoints]]
listen = "0.0.0.0:8080"
remote = "example.com:80"

[[endpoints]]
listen = "0.0.0.0:8443"
remote = "[2001:db8::1]:443"
```

## ❓ 常见问题

**Q: 为什么添加规则后连接不成功？**  
A: 请检查：
1. Realm服务是否运行（选项4查看状态）
2. 防火墙是否放行了端口（选项8检查）
3. 目标服务器是否可访问

**Q: 如何完全卸载Realm？**  
A: 执行以下命令：
```bash
systemctl stop realm
systemctl disable realm
rm -f /usr/local/bin/realm
rm -rf /etc/realm
rm -f /etc/systemd/system/realm.service
```

**Q: 支持IPv6吗？**  
A: 是的，脚本自动识别IPv6地址并添加正确的格式（用方括号包裹）

## 📜 许可证

本项目采用 [GPL-3.0 license](LICENSE)

## 🙏 致谢

- [zhboner/realm](https://github.com/zhboner/realm) - 提供核心转发功能
- 所有镜像源提供者 - 确保安装过程稳定可靠

---

**提示**：建议定期更新脚本以获取最新功能和优化！

我为您提供了您要求的、优化后的完整 Markdown 格式教程，已包含所有的标题、加粗、表格和代码块，确保在 GitHub 上能够完美显示。

````markdown
# 🚀 **macOS High Sierra 终极部署指南（2025-10-29） - Part 1/3**

## **📋 快速总览（总时长：2-4小时）**
| **阶段** | **内容** | **时间** | **关键优化** |
| :--- | :--- | :--- | :--- |
| **0️⃣** | **Mihomo代理**（**网络加速，必先！**） | 10min | 日志轮换+crontab+备份 |
| **1️⃣** | **系统+TLS**（Xcode/MacPorts/OpenSSL） | 15min | 软链接+Git全局修复 |
| **2️⃣** | **Python+PG+Shell** | 20min | **完整bash_profile**（别名+PS1） |
| **3️⃣** | **Emacs IDE**（**精简3文件**） | 15min | Org/Python/SQL/LSP/Magit |
| **4️⃣** | **MIMIC-IV**（导入+概念） | 1-3h | mimic-code自动化 |
| **5️⃣** | **验证+备份脚本** | 10min | **一键Checklist+tar** |

**Tips**：
- **替换 `sue`** 为你的用户名
- **50GB空间** | **代理下载20GB MIMIC**
- **每步表格验证** | **备份先行**
- **下载**：[MacPorts](https://github.com/macports/macports-base/releases/download/v2.11.5/MacPorts-2.11.5-10.13-HighSierra.pkg) | [Miniforge](https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh) | [Postgres](https://github.com/PostgresApp/PostgresApp/releases/download/v2.7.10/Postgres-2.7.10-12-13-14-15-16-17.dmg)

---

## **🧩 阶段0: Mihomo 系统代理（**网络救星，先做！**）**

### **📁 目录结构**
| 路径 | 说明 |
| :--- | :--- |
| `~/.config/mihomo/mihomo` | 主程序（**chmod +x**） |
| `~/.config/mihomo/config.yaml` | 订阅配置 |
| `/Library/LaunchDaemons/com.mihomo.service.plist` | **系统自启** |

### **🧰 Step 0.1: 准备**
```bash
mkdir -p ~/.config/mihomo
chmod +x ~/.config/mihomo/mihomo
file ~/.config/mihomo/mihomo  # Mach-O 64-bit
````

### **⚙️ Step 0.2: 完整plist（**`sudo nano /Library/LaunchDaemons/com.mihomo.service.plist`**，全复制）**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "[http://www.apple.com/DTDs/PropertyList-1.0.dtd](http://www.apple.com/DTDs/PropertyList-1.0.dtd)">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.mihomo.service</string>
  <key>ProgramArguments</key><array>
    <string>/Users/sue/.config/mihomo/mihomo</string><string>-f</string><string>/Users/sue/.config/mihomo/config.yaml</string>
  </array>
  <key>UserName</key><string>sue</string>
  <key>EnvironmentVariables</key><dict><key>HOME</key><string>/Users/sue</string><key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/mihomo.log</string><key>StandardErrorPath</key><string>/tmp/mihomo.log</string>
  <key>WorkingDirectory</key><string>/Users/sue/.config/mihomo</string>
</dict>
</plist>
```

### **🔒 Step 0.3: 加载**

```bash
sudo chown root:wheel /Library/LaunchDaemons/com.mihomo.service.plist
sudo chmod 644 /Library/LaunchDaemons/com.mihomo.service.plist
sudo launchctl unload /Library/LaunchDaemons/com.mihomo.service.plist 2>/dev/null || true
sudo launchctl load /Library/LaunchDaemons/com.mihomo.service.plist
sudo launchctl start com.mihomo.service
```

### **📜 Step 0.4: 日志轮换（crontab）**

```bash
cat > /usr/local/bin/mihomo-logrotate.sh << 'EOF'
#!/bin/bash
LOG="/tmp/mihomo.log"; MAX=1048576
[ -f "$LOG" ] && [ $(stat -f%z "$LOG") -ge $MAX ] && mv "$LOG" "${LOG}.$(date +%Y%m%d%H%M%S)" && touch "$LOG"
EOF
chmod +x /usr/local/bin/mihomo-logrotate.sh
(crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/mihomo-logrotate.sh") | crontab -
```

### **✅ Step 0.5: 验证**

| 命令 | 预期 |
| :--- | :--- |
| `ps aux \| grep mihomo` | 进程运行 |
| `cat /tmp/mihomo.log \| grep API` | `:9090` |
| `curl -x http://127.0.0.1:7890 https://github.com -I` | `HTTP/2 200` |

### **💾 Step 0.6: 备份**

```bash
tar czf ~/mihomo-backup-$(date +%Y%m%d).tar.gz ~/.config/mihomo /Library/LaunchDaemons/com.mihomo.service.plist
```

**🎉 代理就位！**

-----

Would you like me to generate Part 2/3 (System + Shell) of the guide now?

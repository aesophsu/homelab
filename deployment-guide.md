# 🚀 macOS High Sierra 终极部署指南（2025-10-29）

📋 **快速总览（总时长：2-4小时）**
| 阶段 | 内容 | 时间 | 关键优化 |
| :--- | :--- | :--- | :--- |
| 0️⃣ | Mihomo代理（网络加速，必先！） | 10min | 日志轮换+crontab+备份 |
| 1️⃣ | 系统+TLS（Xcode/MacPorts/OpenSSL） | 15min | 软链接+Git全局修复 |
| 2️⃣ | Python+PG+Shell | 20min | 完整bash\_profile（别名+PS1） |
| 3️⃣ | Emacs IDE（精简3文件） | 15min | Org/Python/SQL/LSP/Magit |
| 4️⃣ | MIMIC-IV（导入+概念） | 1-3h | mimic-code自动化 |
| 5️⃣ | 验证+备份脚本 | 10min | 一键Checklist+tar |

**Tips：**

* **替换 `sue`** 为你的用户名
* 50GB空间 | 代理下载20GB MIMIC
* 每步表格验证 | 备份先行
* 下载：[MacPorts](https://www.macports.org/install.php) | [Miniforge](https://github.com/conda-forge/miniforge#miniforge-installers) | [Postgres.app](https://postgresapp.com/)

---

## 🧩 阶段 0: Mihomo 系统代理（网络救星，先做！）

📁 **目录结构**
| 路径 | 说明 |
| :--- | :--- |
| `~/.config/mihomo/mihomo` | 主程序（chmod +x） |
| `~/.config/mihomo/config.yaml` | 订阅配置 |
| `/Library/LaunchDaemons/com.mihomo.service.plist` | 系统自启 |

🧰 **Step 0.1: 准备**
```bash
mkdir -p ~/.config/mihomo
# 假设 mihomo 核心已下载到该路径
chmod +x ~/.config/mihomo/mihomo
file ~/.config/mihomo/mihomo  # 预期: Mach-O 64-bit

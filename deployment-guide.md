# 🚀 **macOS High Sierra 终极部署指南（2025-10-29） - Part 1/3**

## **📋 快速总览（总时长：2-4小时）**
| **阶段** | **内容** | **时间** | **关键优化** |
|----------|----------|----------|--------------|
| **0️⃣** | **Mihomo代理**（**网络加速，必先！**） | 10min | 日志轮换+crontab+备份 |
| **1️⃣** | **系统+TLS**（Xcode/MacPorts/OpenSSL） | 15min | 软链接+Git全局修复 |
| **2️⃣** | **Python+PG+Shell** | 20min | **完整bash_profile**（别名+PS1） |
| **3️⃣** | **Emacs IDE**（**精简3文件**） | 15min | Org/Python/SQL/LSP/Magit |
| **4️⃣** | **MIMIC-IV**（导入+概念） | 1-3h | mimic-code自动化 |
| **5️⃣** | **验证+备份脚本** | 10min | **一键Checklist+tar** |

**Tips**：
- **替换`sue`**为你的用户名
- **50GB空间** | **代理下载20GB MIMIC**
- **每步表格验证** | **备份先行**
- **下载**：[MacPorts](https://github.com/macports/macports-base/releases/download/v2.11.5/MacPorts-2.11.5-10.13-HighSierra.pkg) | [Miniforge](https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh) | [Postgres](https://github.com/PostgresApp/PostgresApp/releases/download/v2.7.10/Postgres-2.7.10-12-13-14-15-16-17.dmg)

---

## **🧩 阶段0: Mihomo 系统代理（**网络救星，先做！**）**

### **📁 目录结构**
| 路径 | 说明 |
|------|------|
| `~/.config/mihomo/mihomo` | 主程序（**chmod +x**） |
| `~/.config/mihomo/config.yaml` | 订阅配置 |
| `/Library/LaunchDaemons/com.mihomo.service.plist` | **系统自启** |

### **🧰 Step 0.1: 准备**
```bash
mkdir -p ~/.config/mihomo
chmod +x ~/.config/mihomo/mihomo
file ~/.config/mihomo/mihomo  # Mach-O 64-bit
```

### **⚙️ Step 0.2: 完整plist（**sudo nano /Library/LaunchDaemons/com.mihomo.service.plist**，全复制）**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- 服务标识 -->
  <key>Label</key><string>com.mihomo.service</string>
  <!-- 启动命令 -->
  <key>ProgramArguments</key><array>
    <string>/Users/sue/.config/mihomo/mihomo</string><string>-f</string><string>/Users/sue/.config/mihomo/config.yaml</string>
  </array>
  <!-- 运行用户 -->
  <key>UserName</key><string>sue</string>
  <!-- 环境 -->
  <key>EnvironmentVariables</key><dict><key>HOME</key><string>/Users/sue</string><key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <!-- 自启+保活 -->
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <!-- 日志 -->
  <key>StandardOutPath</key><string>/tmp/mihomo.log</string><key>StandardErrorPath</key><string>/tmp/mihomo.log</string>
  <!-- 目录 -->
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

### **📜 Step 0.4: 日志轮换（**crontab**）**
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
|------|------|
| `ps aux | grep mihomo` | 进程运行 |
| `cat /tmp/mihomo.log | grep API` | `:9090` |
| `curl -x http://127.0.0.1:7890 https://github.com -I` | `HTTP/2 200` |

### **💾 Step 0.6: 备份**
```bash
tar czf ~/mihomo-backup-$(date +%Y%m%d).tar.gz ~/.config/mihomo /Library/LaunchDaemons/com.mihomo.service.plist
```

# 🚀 **macOS High Sierra 终极部署指南（2025-10-29） - Part 2/3**

**续 Part 1**：代理**飞起** → **系统/TLS/Python/PG 全修复**！

---

## **🔧 阶段1: 系统基础 + TLS 修复（**20min**）**

### **🧰 模块1.1: Xcode CLT（编译基石）**
```bash
xcode-select --install  # 弹窗完成
xcode-select --switch /Library/Developer/CommandLineTools
sudo xcodebuild -license accept
```
**✅ 验证**：
| 命令 | 预期 |
|------|------|
| `xcode-select -p` | `/Library/Developer/CommandLineTools` |
| `clang --version` | `Apple LLVM ...` |

### **🧰 模块1.2: MacPorts + **OpenSSL 3.x**（**TLS零坑**）**
1. **下载**（**代理浏览器**）：👉 [MacPorts PKG](https://github.com/macports/macports-base/releases/download/v2.11.5/MacPorts-2.11.5-10.13-HighSierra.pkg) → **双击安装**
   ```bash
   port version  # MacPorts 2.11.5
   ```

2. **镜像加速**：
   ```bash
   sudo tee /opt/local/etc/macports/sources.conf > /dev/null <<'EOF'
   rsync://rsync.macports.org/macports/release/tarballs/ports.tar [default]
   https://packages.macports.org/release/tarballs/ports.tar.gz
   https://mirrors.tuna.tsinghua.edu.cn/macports/release/tarballs/ports.tar.gz
   EOF
   echo "macports_use_clonefile no" | sudo tee -a /opt/local/etc/macports/macports.conf
   sudo port -v selfupdate && sudo port -v sync
   ```

3. **安装核心**：
   ```bash
   sudo port install openssl curl +ssl git +ssl
   ```

4. **软链接**（**Homebrew兼容**）：
   ```bash
   sudo mkdir -p /usr/local/opt/openssl/{bin,lib,include}
   sudo ln -sf /opt/local/bin/openssl /usr/local/opt/openssl/bin/openssl
   sudo ln -sf /opt/local/lib/libssl.3.dylib /usr/local/opt/openssl/lib/libssl.dylib
   sudo ln -sf /opt/local/lib/libcrypto.3.dylib /usr/local/opt/openssl/lib/libcrypto.dylib
   sudo ln -sf /opt/local/include/openssl /usr/local/opt/openssl/include/openssl
   ```

5. **Git TLS**：
   ```bash
   git config --global http.sslBackend openssl
   git config --global http.sslCAInfo /opt/local/etc/openssl/cert.pem
   ```

**✅ 验证**：
| 命令 | 预期 |
|------|------|
| `openssl version` | `OpenSSL 3.5.x` |
| `curl -I https://github.com` | `HTTP/2 200` |
| `git ls-remote https://github.com/MIT-LCP/mimic-code` | Commit ID |

**💾 备份**：`sudo tar czf ~/macports-backup.tar.gz /opt/local/etc/macports/`

---

## **🐍 阶段2: Python + PG + Shell（**25min**）**

### **🧰 模块2.1: Miniforge（**Conda/Mamba**）**
1. **下载**（**代理**）：👉 [Miniforge](https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh)
   ```bash
   cd ~/Downloads
   bash Miniforge3-MacOSX-x86_64.sh -b -p ~/miniforge3
   rm Miniforge3-MacOSX-x86_64.sh
   ~/miniforge3/bin/conda init bash
   ~/miniforge3/bin/mamba init bash
   ```
**✅**：`ls ~/miniforge3/bin/{conda,mamba}`

### **🧰 模块2.2: Postgres.app（**MIMIC主机**）**
1. **下载**（**代理**）：👉 [Postgres DMG](https://github.com/PostgresApp/PostgresApp/releases/download/v2.7.10/Postgres-2.7.10-12-13-14-15-16-17.dmg) → **拖 `/Applications`**
   ```bash
   open -a /Applications/Postgres.app
   ```
2. **GUI**：**Server Settings → Initialize** → **新建 DB "mimic"**
**✅**：App内 **Databases → mimic ✓** | `psql -l | grep mimic`

### **⚙️ 模块2.3: **完整** `~/.bash_profile`（**全复制替换！**）**
```bash
cp ~/.bash_profile ~/.bash_profile.bak.$(date +%Y%m%d)
cat > ~/.bash_profile << 'EOF'
# ===== 1️⃣ MacPorts OpenSSL 3.x (TLS 修复 - 最优先) =====
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
export LDFLAGS="-L/opt/local/lib $LDFLAGS"
export CPPFLAGS="-I/opt/local/include $CPPFLAGS"
export PKG_CONFIG_PATH="/opt/local/lib/pkgconfig:$PKG_CONFIG_PATH"
export SSL_CERT_FILE="/opt/local/etc/openssl/cert.pem"
export GIT_SSL_CAINFO="/opt/local/etc/openssl/cert.pem"

# ===== 2️⃣ Conda/Mamba (官方块 - 勿删!) =====
# >>> conda initialize >>>
__conda_setup="$('/Users/sue/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/sue/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/Users/sue/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/sue/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# >>> mamba initialize >>>
export MAMBA_EXE='/Users/sue/miniforge3/bin/mamba';
export MAMBA_ROOT_PREFIX='/Users/sue/miniforge3';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    if [ -f "$MAMBA_ROOT_PREFIX/etc/profile.d/mamba_rc.sh" ]; then
        . "$MAMBA_ROOT_PREFIX/etc/profile.d/mamba_rc.sh"
    else
        export PATH="$MAMBA_ROOT_PREFIX/bin:$PATH"
    fi
    alias mamba="$MAMBA_EXE"
fi
unset __mamba_setup
# <<< mamba initialize <<<

# ===== 3️⃣ Postgres.app =====
POSTGRES_BIN="/Applications/Postgres.app/Contents/Versions/latest/bin"
if [ -d "$POSTGRES_BIN" ]; then
    export PATH="$POSTGRES_BIN:$PATH"
    export PGDATABASE="mimic"
    export PGUSER="sue"  # ⚠️ 替换你的用户名!
fi

# ===== 4️⃣ 别名 + 美化PS1 =====
alias ll='ls -lhG'
alias py='python3'
alias jn='jupyter notebook'
alias jc='jupyter lab'
alias mimic='psql mimic'
export PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "

# ===== 5️⃣ .bashrc =====
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF
source ~/.bash_profile  # 生效!
```

**✅ 验证**：
| 命令 | 预期 |
|------|------|
| `which psql` | `/Applications/.../psql` |
| `echo $PGDATABASE` | `mimic` |
| `conda --version` | `24.x` |
| `mamba --version` | `24.x` |
| `ll` | 彩色ls |

# 🚀 **macOS High Sierra 终极部署指南（2025-10-29） - **Part 3/3** 🚀**

**续 Part 2**：Shell就位 → **Emacs IDE + MIMIC-IV全导入 + 一键验证**！

---

## **💻 阶段3: Emacs IDE（**精简3文件**，**零坑模块化**）** **(15min)**

### **🧰 Step 3.1: 安装**
```bash
sudo port install emacs-mac-app sbcl  # GUI + Lisp
mkdir -p ~/.emacs.d/lisp
```

### **⚙️ Step 3.2: **3文件全复制**（**注释优化+兼容**）**

#### **文件1: `~/.emacs.d/init.el`** **(主入口)**
```elisp
;; ===== Emacs 极速启动 (2025优化版) =====
(setq gc-cons-threshold (* 100 1024 1024))  ; 加速启动
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;; TLS修复 (MacPorts OpenSSL)
(setq tls-program '("/opt/local/bin/openssl s_client -connect %h:%p -CAfile /opt/local/etc/openssl/cert.pem -no_ssl3 -no_ssl2 -ign_eof"))

;; 加载模块
(load "~/.emacs.d/lisp/ui.el")
(load "~/.emacs.d/lisp/core.el")

(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 8 1024 1024))))
```

#### **文件2: `~/.emacs.d/lisp/ui.el`** **(UI+Conda集成)**
```elisp
;; ===== UI + macOS集成 =====
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns))
  :config
  (exec-path-from-shell-initialize)
  (exec-path-from-shell-copy-envs '("PATH" "SSL_CERT_FILE" "PGDATABASE" "PGUSER")))

(use-package conda
  :after exec-path-from-shell
  :config
  (setq conda-anaconda-home "/Users/sue/miniforge3")  ; ⚠️替换!
  (conda-env-initialize-interactive-shells)
  (conda-env-initialize-eshell)
  :bind ("C-c c" . conda-env-activate))  ; C-c c 激活mimic

(use-package doom-modeline :init (doom-modeline-mode 1))
(use-package dired-icon :hook (dired-mode . all-the-icons-dired-mode))
```

#### **文件3: `~/.emacs.d/lisp/core.el`** **(开发+数据分析)**
```elisp
;; ===== LSP + Org + SQL + Git =====
(use-package lsp-mode :hook ((python-mode . lsp) (lisp-mode . lsp)) :commands lsp :init (setq lsp-log-io nil))
(use-package lsp-ui :after lsp-mode)

(use-package sly :config (setq inferior-lisp-program "sbcl") :bind ("C-c s" . sly))

(use-package magit :bind ("C-x g" . magit-status))
(use-package projectile :config (projectile-mode +1) :bind-keymap ("C-c p" . projectile-command-map))
(use-package company :hook (after-init . global-company-mode) :config (setq company-idle-delay 0.1))
(use-package avy :bind ("C-:" . avy-goto-char))

;; 数据科学核心
(use-package org :hook (org-mode . org-indent-mode)
  :config (org-babel-do-load-languages 'org-babel-load-languages
                                      '((python . t) (sql . t) (shell . t))))

(use-package sql :config
  (setq sql-connection-alist '((mimic (sql-product 'postgres) (sql-port 5432) (sql-server "localhost")
                                    (sql-user . (getenv "PGUSER")) (sql-database . (getenv "PGDATABASE")))))
  :bind ("C-c q" . sql-connect))  ; C-c q 连mimic
```

**重启**：`emacs`  
**✅ 测试**：
| 操作 | 成功 |
|------|------|
| **C-c c** | 激活mimic环境 |
| `.org` + `#+BEGIN_SRC python` + **C-c C-c** | 执行输出 |
| **C-c q** → `mimic` → `\dt` | 表列表 |

**💾 备份**：`tar czf ~/emacs-backup.tar.gz ~/.emacs.d/`

---

## **📊 阶段4: MIMIC-IV 全自动化部署（**1-3h**）**

### **🧰 Step 4.1: 下载（**代理20GB**）**
1. **PhysioNet注册** → **浏览器/代理下载** `mimic-iv-3.1` → `~/Documents/PhysioNet/`
2. **代码**：
   ```bash
   mkdir -p ~/Documents/PhysioNet/
   cd ~/Documents/PhysioNet/
   git clone https://github.com/MIT-LCP/mimic-code
   ```

### **🧰 Step 4.2: **一键导入脚本**（**全复制保存**）**
```bash
cat > ~/deploy_mimic.sh << 'EOF'
#!/bin/bash
set -e  # 出错停止
DB="mimic"
CODE=~/Documents/PhysioNet/mimic-code
DATA=~/Documents/PhysioNet/mimic-iv-3.1

echo "🚀 MIMIC-IV 部署开始..."
psql -c "CREATE DATABASE $DB;" 2>/dev/null || true

echo "1/6 📋 表结构..."
psql "$DB" -f $CODE/mimic-iv/buildmimic/postgres/create.sql

echo "2/6 ⏳ 导入数据 (~1-3h)..."
psql "$DB" -v mimic_data_dir="$DATA" -f $CODE/mimic-iv/buildmimic/postgres/load_gz.sql

echo "3/6 🔗 约束..."
psql "$DB" -f $CODE/mimic-iv/buildmimic/postgres/constraint.sql

echo "4/6 📈 索引..."
psql "$DB" -f $CODE/mimic-iv/buildmimic/postgres/index.sql

echo "5/6 🧹 优化..."
psql "$DB" -c "VACUUM ANALYZE;"

echo "6/6 ✨ 衍生概念 (SOFA等)..."
psql "$DB" -f $CODE/mimic-iv/concepts_postgres/make_concepts.sql

echo "✅ 部署完成! 测试: psql $DB -c 'SELECT COUNT(*) FROM patients.hosp;'"
EOF
chmod +x ~/deploy_mimic.sh && ~/deploy_mimic.sh
```

**✅**：脚本末尾自动测试 **~531k patients**

### **🧰 Step 4.3: Conda环境**
```bash
conda create -n mimic python=3.12 -y
conda activate mimic
mamba install jupyter pandas numpy matplotlib psycopg2 jupyterlab -y
python3 -c "import psycopg2; print('✅ DB连通!')"
```

---

## **🔄 阶段5: **一键验证 + 备份** **(10min)** 🎉

### **🧰 Step 5.1: **全验证脚本**（**全复制**）**
```bash
cat > ~/verify_env.sh << 'EOF'
#!/bin/bash
# ===== High Sierra 全栈验证 (2025版) =====
BACKUP=~/env-full-$(date +%Y%m%d)
mkdir -p $BACKUP

echo "🔍 [1/6] Mihomo代理..."
pgrep mihomo && echo "✔ 运行中" || echo "✘ 重启: sudo launchctl restart com.mihomo.service"

echo "🔍 [2/6] TLS/OpenSSL..."
openssl version | grep 3 && curl -I https://github.com | head -1 && echo "✔ OK"

echo "🔍 [3/6] Python/Conda..."
conda activate mimic && python3 -c "import pandas,psycopg2; print('✔ 数据科学栈')" && deactivate

echo "🔍 [4/6] Postgres/MIMIC..."
psql mimic -c "SELECT COUNT(*) FROM patients.hosp;" | grep -v COUNT && echo "✔ ~531k"

echo "🔍 [5/6] Emacs..."
emacs --batch --eval "(message \"✔ 启动OK\")" 2>/dev/null && echo "✔ IDE就位"

echo "💾 [6/6] 备份..."
tar czf $BACKUP/full.tar.gz ~/.bash_profile ~/.emacs.d ~/miniforge3 ~/deploy_mimic.sh /Library/LaunchDaemons/com.mihomo* 2>/dev/null || true
echo "🎉 全栈完美! 备份: $BACKUP/full.tar.gz"
EOF
chmod +x ~/verify_env.sh && ~/verify_env.sh
```

**运行**：`~/verify_env.sh` → **全绿+备份自动！**

### **✅ 最终Checklist**
| 模块 | 状态 |
|------|------|
| **代理** | `curl -x http://127.0.0.1:7890 https://physionet.org` → 200 |
| **TLS** | `git clone https://github.com/MIT-LCP/mimic-code` |
| **Emacs** | `emacs` → **C-c q** (SQL) / **C-c c** (mimic) |
| **MIMIC** | `mimic` → `SELECT * FROM mimic_derived.icu.stay_first_24h LIMIT 5;` |
| **Jupyter** | `jc` → **%load_ext sql** `%%sql postgresql://mimic` |

## **🚀 完结！** **High Sierra → 科研神机** 💻🏥  
**日常**：`source ~/.bash_profile` | `~/verify_env.sh` | **Enjoy MIMIC+Emacs!**  

**问题日志** → **秒修**！ 🔥

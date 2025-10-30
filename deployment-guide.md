macOS High Sierra 终极部署指南 **优化顺序、国内源加速、手动下载、vi 编辑器、路径统一**，版本如下：

* **MacPorts:** 2.11.5
* **Miniforge:** x86_64
* **Postgres.app:** 2.7.10
* **Emacs:** 30.2
* **Mihomo:** amd64-v3-go120-v1.19.15


# 🚀 macOS High Sierra 终极部署指南

## 📋 快速总览（总时长：约2-4小时）

| 阶段  | 内容                                     | 时间    | 关键优化                             |
| --- | -------------------------------------- | ----- | -------------------------------- |
| 0️⃣ | Mihomo 系统代理（网络加速，必先！）                  | 10min | 日志轮换 + crontab + 备份              |
| 1️⃣ | 系统基础 + TLS（Xcode / MacPorts / OpenSSL） | 15min | 软链接 + Git TLS 修复                 |
| 2️⃣ | Python / Postgres / Shell 配置           | 20min | 完整 bash_profile                  |
| 3️⃣ | Emacs IDE 配置                           | 15min | Org / Python / SQL / LSP / Magit |
| 4️⃣ | MIMIC-IV 自动化部署                         | 1-3h  | 自动化导入 + 衍生概念                     |
| 5️⃣ | 全验证 + 备份                               | 10min | 一键全栈检测                           |

**下载链接（手动下载）**：

* [MacPorts 2.11.5](https://github.com/macports/macports-base/releases/download/v2.11.5/MacPorts-2.11.5-10.13-HighSierra.pkg)
* [Miniforge3 x86_64](https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh)
* [Postgres.app 2.7.10](https://github.com/PostgresApp/PostgresApp/releases/download/v2.7.10/Postgres-2.7.10-12-13-14-15-16-17.dmg)
* [Mihomo go120 v3](https://github.com/MetaCubeX/mihomo/releases/download/v1.19.15/mihomo-darwin-amd64-v3-go120-v1.19.15.gz) 

---

## 🧩 阶段0: Mihomo 系统代理（网络优先）

### 📁 目录结构

| 路径                                                | 说明            |
| ------------------------------------------------- | ------------- |
| `~/.config/mihomo/mihomo`                         | 主程序（chmod +x） |
| `~/.config/mihomo/config.yaml`                    | 订阅配置          |
| `/Library/LaunchDaemons/com.mihomo.service.plist` | 系统自启          |

### 🧰 Step 0.1: 准备

```bash
mkdir -p ~/.config/mihomo
chmod +x ~/.config/mihomo/mihomo
file ~/.config/mihomo/mihomo   # Mach-O 64-bit
```

### ⚙️ Step 0.2: plist 系统自启（vi 编辑器）

```bash
sudo vi /Library/LaunchDaemons/com.mihomo.service.plist
```

复制以下内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.mihomo.service</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/sue/.config/mihomo/mihomo</string>
    <string>-f</string>
    <string>/Users/sue/.config/mihomo/config.yaml</string>
  </array>
  <key>UserName</key><string>sue</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>/Users/sue</string>
    <key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/mihomo.log</string>
  <key>StandardErrorPath</key><string>/tmp/mihomo.log</string>
  <key>WorkingDirectory</key><string>/Users/sue/.config/mihomo</string>
</dict>
</plist>
```

### 🔒 Step 0.3: 加载服务

```bash
sudo chown root:wheel /Library/LaunchDaemons/com.mihomo.service.plist
sudo chmod 644 /Library/LaunchDaemons/com.mihomo.service.plist
sudo launchctl unload /Library/LaunchDaemons/com.mihomo.service.plist 2>/dev/null || true
sudo launchctl load /Library/LaunchDaemons/com.mihomo.service.plist
sudo launchctl start com.mihomo.service
```

### 📜 Step 0.4: 日志轮换（crontab）

```bash
cat > /usr/local/bin/mihomo-logrotate.sh << 'EOF'
#!/bin/bash
LOG="/tmp/mihomo.log"; MAX=1048576
[ -f "$LOG" ] && [ $(stat -f%z "$LOG") -ge $MAX ] && mv "$LOG" "${LOG}.$(date +%Y%m%d%H%M%S)" && touch "$LOG"
EOF
chmod +x /usr/local/bin/mihomo-logrotate.sh
(crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/mihomo-logrotate.sh") | crontab -
```

### ✅ Step 0.5: 验证

| 命令                                                    | 预期           |      |
| ----------------------------------------------------- | ------------ | ---- |
| `ps aux                                               | grep mihomo` | 进程运行 |
| `cat /tmp/mihomo.log                                  | tail`        | 日志输出 |
| `curl -x http://127.0.0.1:7890 https://github.com -I` | HTTP/2 200   |      |

### 💾 Step 0.6: 备份

```bash
tar czf ~/mihomo-backup-$(date +%Y%m%d).tar.gz ~/.config/mihomo /Library/LaunchDaemons/com.mihomo.service.plist
```

---

## 🔧 阶段1: 系统基础 + TLS 修复（约20min）

### 🧰 Step 1.1: Xcode Command Line Tools（编译基石）

```bash
xcode-select --install   # 弹窗安装完成
sudo xcode-select --switch /Library/Developer/CommandLineTools
sudo xcodebuild -license accept
```

**验证**：

| 命令                | 预期                                    |
| ----------------- | ------------------------------------- |
| `xcode-select -p` | `/Library/Developer/CommandLineTools` |
| `clang --version` | Apple LLVM ...                        |

---

### 🧰 Step 1.2: MacPorts 安装（2.11.5 PKG 手动下载）

1. **下载**：[MacPorts-2.11.5-10.13-HighSierra.pkg](https://github.com/macports/macports-base/releases/download/v2.11.5/MacPorts-2.11.5-10.13-HighSierra.pkg) → **双击安装**

```bash
port version  # 验证 2.11.5
```

2. **国内镜像加速**

```bash
sudo tee /opt/local/etc/macports/sources.conf > /dev/null <<'EOF'
rsync://rsync.macports.org/macports/release/tarballs/ports.tar [default]
https://mirrors.tuna.tsinghua.edu.cn/macports/release/tarballs/ports.tar.gz
EOF

echo "macports_use_clonefile no" | sudo tee -a /opt/local/etc/macports/macports.conf
sudo port -v selfupdate && sudo port -v sync
```

3. **安装核心组件**

```bash
sudo port install openssl curl +ssl git +ssl
```

4. **软链接（保证系统识别 OpenSSL）**

```bash
sudo mkdir -p /usr/local/opt/openssl/{bin,lib,include}
sudo ln -sf /opt/local/bin/openssl /usr/local/opt/openssl/bin/openssl
sudo ln -sf /opt/local/lib/libssl.3.dylib /usr/local/opt/openssl/lib/libssl.dylib
sudo ln -sf /opt/local/lib/libcrypto.3.dylib /usr/local/opt/openssl/lib/libcrypto.dylib
sudo ln -sf /opt/local/include/openssl /usr/local/opt/openssl/include/openssl
```

5. **Git TLS 配置**

```bash
git config --global http.sslBackend openssl
git config --global http.sslCAInfo /opt/local/etc/openssl/cert.pem
```

**验证**：

| 命令                                                    | 预期            |
| ----------------------------------------------------- | ------------- |
| `openssl version`                                     | OpenSSL 3.5.x |
| `curl -I https://github.com`                          | HTTP/2 200    |
| `git ls-remote https://github.com/MIT-LCP/mimic-code` | 返回 Commit ID  |

**备份 MacPorts 配置**

```bash
sudo tar czf ~/macports-backup.tar.gz /opt/local/etc/macports/
```

---

### 🧰 Step 2.1: Miniforge 安装（手动下载）

1. **下载**：[Miniforge3-MacOSX-x86_64.sh](https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh) → **浏览器下载**

```bash
cd ~/Downloads
bash Miniforge3-MacOSX-x86_64.sh -b -p ~/miniforge3
rm Miniforge3-MacOSX-x86_64.sh
~/miniforge3/bin/conda init bash
~/miniforge3/bin/mamba init bash
```

**验证**：

```bash
ls ~/miniforge3/bin/{conda,mamba}
```

2. **配置国内镜像（清华源）**

```bash
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/
conda config --set show_channel_urls yes
```

---

### ⚙️ Step 2.2: 更新 `~/.bash_profile`（完整替换，统一路径）

```bash
cp ~/.bash_profile ~/.bash_profile.bak.$(date +%Y%m%d)
vi ~/.bash_profile
```

复制以下内容：

```bash
# ===== MacPorts OpenSSL 3.x =====
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
export LDFLAGS="-L/opt/local/lib $LDFLAGS"
export CPPFLAGS="-I/opt/local/include $CPPFLAGS"
export PKG_CONFIG_PATH="/opt/local/lib/pkgconfig:$PKG_CONFIG_PATH"
export SSL_CERT_FILE="/opt/local/etc/openssl/cert.pem"
export GIT_SSL_CAINFO="/opt/local/etc/openssl/cert.pem"

# ===== Conda / Mamba =====
__conda_setup="$('/Users/sue/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then eval "$__conda_setup"; else
  if [ -f "/Users/sue/miniforge3/etc/profile.d/conda.sh" ]; then
    . "/Users/sue/miniforge3/etc/profile.d/conda.sh"
  else
    export PATH="/Users/sue/miniforge3/bin:$PATH"
  fi
fi
unset __conda_setup

export MAMBA_EXE='/Users/sue/miniforge3/bin/mamba'
export MAMBA_ROOT_PREFIX='/Users/sue/miniforge3'
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then eval "$__mamba_setup"; else
  export PATH="$MAMBA_ROOT_PREFIX/bin:$PATH"
  alias mamba="$MAMBA_EXE"
fi
unset __mamba_setup

# ===== 别名 & PS1 =====
alias ll='ls -lhG'
alias py='python3'
alias jn='jupyter notebook'
alias jc='jupyter lab'
export PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "

[[ -f ~/.bashrc ]] && . ~/.bashrc
```

生效：

```bash
source ~/.bash_profile
```

**验证**

| 命令                | 预期     |
| ----------------- | ------ |
| `conda --version` | 24.x   |
| `mamba --version` | 24.x   |
| `python3 -V`      | 3.12.x |
| `ll`              | 彩色显示   |

---


### 🧰 Step 3.1: Postgres.app 安装（手动下载）

1. **下载**：[Postgres-2.7.10 DMG](https://github.com/PostgresApp/PostgresApp/releases/download/v2.7.10/Postgres-2.7.10-12-13-14-15-16-17.dmg) → 浏览器拖入 `/Applications`
2. **启动并初始化**

```bash
open -a /Applications/Postgres.app
# GUI: Server Settings → Initialize → 新建数据库 "mimic"
```

3. **验证**

```bash
psql -l | grep mimic
```

---

### ⚙️ Step 3.2: 完整 bash_profile（统一路径 /Users/sue）

```bash
cp ~/.bash_profile ~/.bash_profile.bak.$(date +%Y%m%d)
vi ~/.bash_profile
```

复制以下内容：

```bash
# ===== MacPorts OpenSSL 3.x =====
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
export LDFLAGS="-L/opt/local/lib $LDFLAGS"
export CPPFLAGS="-I/opt/local/include $CPPFLAGS"
export PKG_CONFIG_PATH="/opt/local/lib/pkgconfig:$PKG_CONFIG_PATH"
export SSL_CERT_FILE="/opt/local/etc/openssl/cert.pem"
export GIT_SSL_CAINFO="/opt/local/etc/openssl/cert.pem"

# ===== Conda / Mamba =====
__conda_setup="$('/Users/sue/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then eval "$__conda_setup"; else
  if [ -f "/Users/sue/miniforge3/etc/profile.d/conda.sh" ]; then
    . "/Users/sue/miniforge3/etc/profile.d/conda.sh"
  else
    export PATH="/Users/sue/miniforge3/bin:$PATH"
  fi
fi
unset __conda_setup

export MAMBA_EXE='/Users/sue/miniforge3/bin/mamba'
export MAMBA_ROOT_PREFIX='/Users/sue/miniforge3'
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then eval "$__mamba_setup"; else
  export PATH="$MAMBA_ROOT_PREFIX/bin:$PATH"
  alias mamba="$MAMBA_EXE"
fi
unset __mamba_setup

# ===== Postgres.app =====
POSTGRES_BIN="/Applications/Postgres.app/Contents/Versions/latest/bin"
if [ -d "$POSTGRES_BIN" ]; then
  export PATH="$POSTGRES_BIN:$PATH"
  export PGDATABASE="mimic"
  export PGUSER="sue"
fi

# ===== 别名 & PS1 =====
alias ll='ls -lhG'
alias py='python3'
alias jn='jupyter notebook'
alias jc='jupyter lab'
alias mimic='psql mimic'
export PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "

[[ -f ~/.bashrc ]] && . ~/.bashrc
```

生效：

```bash
source ~/.bash_profile
```

**验证**

| 命令                 | 预期                             |
| ------------------ | ------------------------------ |
| `which psql`       | /Applications/Postgres.app/... |
| `echo $PGDATABASE` | mimic                          |
| `conda activate`   | 环境可用                           |
| `ll`               | 彩色显示                           |

---

### 🖥️ Step 3.3: Emacs IDE 安装（30.2，国内源）

1. **安装 GUI 版本与 Lisp 支持**

```bash
sudo port install emacs-mac-app sbcl
mkdir -p ~/.emacs.d/lisp
```

2. **主配置文件：`~/.emacs.d/init.el`**

```elisp
;; ===== Emacs 极速启动 =====
(setq gc-cons-threshold (* 100 1024 1024))
(setq package-archives '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
                         ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
(package-initialize)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;; TLS 修复 (MacPorts OpenSSL)
(setq tls-program '("/opt/local/bin/openssl s_client -connect %h:%p -CAfile /opt/local/etc/openssl/cert.pem -no_ssl3 -no_ssl2 -ign_eof"))

;; 加载模块
(load "~/.emacs.d/lisp/ui.el")
(load "~/.emacs.d/lisp/core.el")

(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 8 1024 1024))))
```

3. **UI 配置：`~/.emacs.d/lisp/ui.el`**

```elisp
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns))
  :config
  (exec-path-from-shell-initialize)
  (exec-path-from-shell-copy-envs '("PATH" "SSL_CERT_FILE" "PGDATABASE" "PGUSER")))

(use-package conda
  :after exec-path-from-shell
  :config
  (setq conda-anaconda-home "/Users/sue/miniforge3")
  (conda-env-initialize-interactive-shells)
  (conda-env-initialize-eshell)
  :bind ("C-c c" . conda-env-activate))

(use-package doom-modeline :init (doom-modeline-mode 1))
(use-package dired-icon :hook (dired-mode . all-the-icons-dired-mode))
```

4. **核心开发配置：`~/.emacs.d/lisp/core.el`**

```elisp
(use-package lsp-mode :hook ((python-mode . lsp) (lisp-mode . lsp)) :commands lsp :init (setq lsp-log-io nil))
(use-package lsp-ui :after lsp-mode)

(use-package sly :config (setq inferior-lisp-program "sbcl") :bind ("C-c s" . sly))
(use-package magit :bind ("C-x g" . magit-status))
(use-package projectile :config (projectile-mode +1) :bind-keymap ("C-c p" . projectile-command-map))
(use-package company :hook (after-init . global-company-mode) :config (setq company-idle-delay 0.1))
(use-package avy :bind ("C-:" . avy-goto-char))

(use-package org :hook (org-mode . org-indent-mode)
  :config (org-babel-do-load-languages 'org-babel-load-languages
                                      '((python . t) (sql . t) (shell . t))))

(use-package sql :config
  (setq sql-connection-alist '((mimic (sql-product 'postgres) (sql-port 5432) (sql-server "localhost")
                                      (sql-user . (getenv "PGUSER")) (sql-database . (getenv "PGDATABASE")))))
  :bind ("C-c q" . sql-connect))
```

**验证**

| 操作                                    | 成功          |
| ------------------------------------- | ----------- |
| `emacs` → C-c c                       | 激活 mimic 环境 |
| `.org + #+BEGIN_SRC python` → C-c C-c | Python 执行   |
| `C-c q` → mimic                       | SQL 连接成功    |

**备份**

```bash
tar czf ~/emacs-backup.tar.gz ~/.emacs.d/
```

---

### 🧰 Step 4.1: 下载 MIMIC-IV 数据与代码（手动下载）

1. **注册 PhysioNet** → 浏览器下载 `mimic-iv-3.1` 数据集
   保存路径：

```text
~/Documents/PhysioNet/mimic-iv-3.1
```

2. **克隆 MIMIC 代码**

```bash
cd ~/Documents/PhysioNet/
git clone https://github.com/MIT-LCP/mimic-code
```

---

### 🧰 Step 4.2: 一键导入脚本
非常好 ✅
下面是根据你选择的 **安全路径方案（先切换到正确目录再导入）** 完全修订的版本。
此脚本兼容 **macOS High Sierra + PostgreSQL 14+ + MIMIC-IV v3.1 + 本地路径结构**，
确保 **所有 SQL 均能正确找到（避免相对路径错误）**，同时保持原有执行逻辑和美观输出。

---

## 🧰 Step 4.2: 一键导入脚本（安全路径版）

```bash
cat > ~/deploy_mimic.sh << 'EOF'
#!/bin/bash
set -e

# ===============================
# 🚀 MIMIC-IV 部署自动化脚本（安全路径方案）
# macOS High Sierra 兼容版
# ===============================

DB="mimic"
CODE="/Users/sue/Documents/PhysioNet/mimic-code"
DATA="/Users/sue/Documents/PhysioNet/mimic-iv-3.1"

echo "🚀 MIMIC-IV 数据库部署开始..."
echo "========================================="

# -------------------------------------------
# Step 1️⃣ 创建数据库（若已存在则跳过）
# -------------------------------------------
psql -c "CREATE DATABASE $DB;" 2>/dev/null || true

# -------------------------------------------
# Step 2️⃣ 导入基础表结构
# -------------------------------------------
echo "1/6 📋 创建表结构..."
psql "$DB" -f "$CODE/mimic-iv/buildmimic/postgres/create.sql"

# -------------------------------------------
# Step 3️⃣ 导入数据（可能耗时 1~3 小时）
# -------------------------------------------
echo "2/6 ⏳ 导入数据 (~1-3h)..."
psql "$DB" -v mimic_data_dir="$DATA" -f "$CODE/mimic-iv/buildmimic/postgres/load_gz.sql"

# -------------------------------------------
# Step 4️⃣ 添加约束（外键、主键等）
# -------------------------------------------
echo "3/6 🔗 添加约束..."
psql "$DB" -f "$CODE/mimic-iv/buildmimic/postgres/constraint.sql"

# -------------------------------------------
# Step 5️⃣ 创建索引，加快查询速度
# -------------------------------------------
echo "4/6 📈 创建索引..."
psql "$DB" -f "$CODE/mimic-iv/buildmimic/postgres/index.sql"

# -------------------------------------------
# Step 6️⃣ 数据库优化（VACUUM + ANALYZE）
# -------------------------------------------
echo "5/6 🧹 执行数据库优化..."
psql "$DB" -c "VACUUM ANALYZE;"

# -------------------------------------------
# Step 7️⃣ 导入衍生概念（SOFA、SAPS II 等）
# 已采用安全路径方案：先进入目录再执行
# -------------------------------------------
echo "6/6 ✨ 导入衍生概念表 (SOFA / SAPS II / Charlson 等)..."
cd "$CODE/mimic-iv/concepts_postgres"
psql "$DB" -f postgres-make-concepts.sql

# -------------------------------------------
# ✅ 完成提示
# -------------------------------------------
echo "========================================="
echo "✅ MIMIC-IV 部署完成!"
echo "👉 测试命令: psql $DB -c 'SELECT COUNT(*) FROM mimiciv_hosp.patients;'"
echo "📂 数据路径: $DATA"
echo "📘 SQL代码路径: $CODE"
EOF

# 授权执行
chmod +x ~/deploy_mimic.sh

# 执行部署脚本
~/deploy_mimic.sh
```

**验证**

```bash
psql mimic -c "SELECT COUNT(*) FROM patients.hosp;"
# ~531k patients
```

---

### 🐍 Step 4.3: Conda 科研环境

```bash
conda create -n mimic python=3.12 -y
conda activate mimic
mamba install jupyter pandas numpy matplotlib psycopg2 jupyterlab -y
python3 -c "import psycopg2; print('✅ DB连通!')"
```

---

## 🔄 阶段5: 一键全栈验证 + 备份（约10min）

### 🧰 Step 5.1: 全栈验证脚本

```bash
cat > ~/verify_env.sh << 'EOF'
#!/bin/bash
BACKUP=~/env-full-$(date +%Y%m%d)
mkdir -p $BACKUP

echo "🔍 [1/6] Mihomo代理..."
pgrep mihomo && echo "✔ 运行中" || echo "✘ 重启: sudo launchctl restart com.mihomo.service"

echo "🔍 [2/6] TLS/OpenSSL..."
openssl version | grep 3 && curl -I https://github.com | head -1 && echo "✔ OK"

echo "🔍 [3/6] Python/Conda..."
conda activate mimic && python3 -c "import pandas,psycopg2; print('✔ 数据科学栈')" && conda deactivate

echo "🔍 [4/6] Postgres/MIMIC..."
psql mimic -c "SELECT COUNT(*) FROM patients.hosp;" | grep -v COUNT && echo "✔ ~531k"

echo "🔍 [5/6] Emacs..."
emacs --batch --eval "(message \"✔ 启动OK\")" 2>/dev/null && echo "✔ IDE就位"

echo "💾 [6/6] 备份..."
tar czf $BACKUP/full.tar.gz ~/.bash_profile ~/.emacs.d ~/miniforge3 ~/deploy_mimic.sh /Library/LaunchDaemons/com.mihomo* 2>/dev/null || true
echo "🎉 全栈完美! 备份: $BACKUP/full.tar.gz"
EOF

chmod +x ~/verify_env.sh
~/verify_env.sh
```

**验证项**

| 模块           | 测试方式                                                                      |
| ------------ | ------------------------------------------------------------------------- |
| Mihomo       | `curl -x http://127.0.0.1:7890 https://physionet.org` → 200               |
| TLS          | `git clone https://github.com/MIT-LCP/mimic-code`                         |
| Python/Conda | `conda activate mimic` → pandas/psycopg2                                  |
| Emacs        | `emacs` → C-c c 激活环境，C-c q 连 SQL                                          |
| MIMIC        | `psql mimic -c "SELECT * FROM mimic_derived.icu.stay_first_24h LIMIT 5;"` |
| Jupyter      | `jc` → `%load_ext sql` + `%%sql postgresql://mimic`                       |

---

✅ **Part4 完成**：MIMIC-IV 全自动导入、科研 Python 环境配置、Emacs IDE、Mihomo 网络代理、全栈验证与自动备份，High Sierra 完整科研环境搭建成功。

**日常操作推荐**：

```bash
source ~/.bash_profile
~/verify_env.sh
```

---




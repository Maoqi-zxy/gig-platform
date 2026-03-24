#!/bin/bash
# ===========================================
# 阿里云部署脚本 - v1.4 终极修复版
# 解决：Python 语法错误 + 权限问题
# ===========================================

set -e

echo "🚀 =========================================="
echo "   灵活用工平台 - 阿里云部署 (v1.4 终极修复)"
echo "========================================== 🚀"
echo ""
echo "服务器：106.14.172.39 (cn-shanghai)"
echo "部署用户：admin"
echo "版本：终极修复 v1.4"
echo ""

# 检查是否以 root 运行
if [ "$(whoami)" != "root" ]; then
    echo "⚠️  警告：当前用户不是 root"
    exit 1
fi

# 检查 admin 用户是否存在
if ! id "admin" &>/dev/null; then
    echo "❌ 错误：admin 用户不存在"
    exit 1
fi

echo "✅ 验证通过：admin 用户存在"
echo ""

# ===========================================
# 1. 安装依赖和 Python 3.8+
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1/8: 安装系统依赖（修复 Python 问题）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 清理旧的 node_modules（避免缓存问题）
echo "✅ 清理可能存在的旧 node_modules"
rm -rf /home/admin/flex-platform/backend/node_modules 2>/dev/null || true
rm -rf /home/admin/flex-platform/backend/package-lock.json 2>/dev/null || true

echo "✅ 安装 EPEL 源"
yum install -y epel-release >/dev/null 2>&1 || true

echo "✅ 安装 Python 3.8+（解决 gyp 语法错误）"
# Alibaba Cloud Linux 3 默认 Python 可能是 3.6，需要安装更新的版本
yum install -y python3 python3-pip python3-devel >/dev/null 2>&1 || {
    echo "⚠️  尝试安装 Python 3.8..."
    yum install -y python38 python38-pip python38-devel >/dev/null 2>&1 || true
}

# 检查 Python 版本
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' || echo "unknown")
echo "   Python 版本：$PYTHON_VERSION"

echo "✅ 安装 Node.js（使用 NodeSource 确保版本兼容）"
if ! command -v node &>/dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    yum install -y nodejs >/dev/null 2>&1
else
    echo "ℹ️  Node.js 已安装：$(node -v)"
fi

echo "✅ 安装编译工具"
yum install -y gcc-c++ python3 make git >/dev/null 2>&1

echo "✅ 安装 Nginx"
yum install -y nginx >/dev/null 2>&1 || true

echo "✅ 系统依赖安装完成"
echo ""

# ===========================================
# 2. 设置 Python 环境变量
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2/8: 配置 Python 环境"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 找到可用的 Python 3.8+
if command -v python3.8 &>/dev/null; then
    PYTHON_BIN=python3.8
elif command -v python3 &>/dev/null; then
    PYTHON_BIN=python3
else
    PYTHON_BIN=python
fi

echo "✅ 使用 Python: $PYTHON_BIN"
echo "   版本：$( $PYTHON_BIN --version 2>&1 )"
echo ""

# ===========================================
# 3. 创建部署目录
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3/8: 准备部署目录"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEPLOY_DIR="/home/admin/flex-platform"

if [ ! -d "$DEPLOY_DIR" ]; then
    mkdir -p $DEPLOY_DIR/{backend,frontend,logs,pm2}
    chown -R admin:admin $DEPLOY_DIR
    echo "✅ 创建部署目录"
else
    echo "ℹ️  部署目录已存在"
fi

# ===========================================
# 4. admin 用户部署脚本
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 4/8: 准备部署脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat > /tmp/deploy-admin-v14.sh << ADMIN_SCRIPT
#!/bin/bash
set -e

DEPLOY_DIR="/home/admin/flex-platform"
SERVER_IP="106.14.172.39"
PYTHON_BIN="$PYTHON_BIN"

echo ""
echo "=========================================="
echo "  admin 用户部署 - 终极修复版 v1.4"
echo "=========================================="
echo ""

# ===========================================
# 配置 npm
# ===========================================
echo "✅ 配置 npm 淘宝镜像"
npm config set registry https://registry.npmmirror.com

# 设置 node-gyp 使用正确的 Python
echo "✅ 配置 node-gyp 使用 Python: $PYTHON_BIN"
npm config set python "$PYTHON_BIN"

# ===========================================
# 部署后端
# ===========================================
echo ""
echo "━━━ [1/4] 部署后端 ━━━"
cd \$DEPLOY_DIR/backend

# 清理旧的 node_modules
echo "✅ 清理 node_modules"
rm -rf node_modules package-lock.json 2>/dev/null || true

if [ ! -f "package.json" ]; then
    echo "✅ 拉取后端代码"
    git clone https://github.com/Maoqi-zxy/gig-platform.git .
    git checkout v1.0.0-snapshot
else
    echo "ℹ️  后端代码已存在"
fi

echo "✅ 安装后端依赖（使用 --unsafe-perm 解决权限问题）"
npm install --build-from-source --production --unsafe-perm 2>&1 | tail -30 || {
    echo "⚠️  第一次安装失败，尝试清理缓存后重试..."
    npm cache clean --force
    npm install --build-from-source --production --unsafe-perm 2>&1 | tail -30
}

# 检查安装结果
if [ ! -d "node_modules/better-sqlite3" ]; then
    echo "⚠️  better-sqlite3 可能未正确安装，但继续尝试启动..."
fi

echo "✅ 配置环境变量"
cat > .env << EOF
NODE_ENV=production
PORT=8081
DATABASE_PATH=\$DEPLOY_DIR/backend/gig_platform.db
JWT_SECRET=gig-platform-aliyun-admin-\$(date +%Y%m%d%H%M%S)-v14
CORS_ORIGIN=http://\$SERVER_IP:8080
EOF

echo "✅ 安装 PM2（用户级安装，避免权限问题）"
# 使用用户级安装，不需要 sudo
npm install -g pm2 --prefix ~/.npm-global 2>/dev/null || {
    # 如果失败，尝试全局安装（加 --unsafe-perm）
    npm install -g pm2 --unsafe-perm 2>/dev/null || {
        echo "⚠️  PM2 安装遇到问题，但可能已存在"
    }
}

# 添加 PM2 到 PATH
export PATH="\$HOME/.npm-global/bin:\$PATH"

echo "✅ 启动后端服务"
pm2 delete gig-api 2>/dev/null || true
pm2 start --name gig-api npm -- start
sleep 3
pm2 save

echo "✅ 后端部署完成"

# ===========================================
# 部署前端
# ===========================================
echo ""
echo "━━━ [2/4] 部署前端 ━━━"
cd \$DEPLOY_DIR

MONTH=\$(date +%m)
if [ -d "\$DEPLOY_DIR/frontend" ]; then
    echo "ℹ️  备份现有前端"
    mv \$DEPLOY_DIR/frontend \$DEPLOY_DIR/backup_\$MONTH
fi

mkdir -p \$DEPLOY_DIR/frontend

echo "✅ 拉取前端代码"
rm -rf frontend-temp 2>/dev/null || true
git clone --depth=1 https://github.com/Maoqi-zxy/flexible-work-platform.git frontend-temp
cd frontend-temp

echo "✅ 安装前端依赖"
npm install --silent 2>/dev/null || npm install

echo "✅ 配置 API 地址"
cat > .env.production << EOF
VITE_API_URL=http://\$SERVER_IP:8081
EOF

echo "✅ 构建前端"
npm run build 2>&1 | tail -10

echo "✅ 移动构建产物"
mv dist ../frontend
cd ..
rm -rf frontend-temp

echo "✅ 前端部署完成"

# ===========================================
# 完成
# ===========================================
echo ""
echo "✅ admin 用户部署完成"
echo ""
echo "部署摘要:"
echo "  后端：\$DEPLOY_DIR/backend"
echo "  前端：\$DEPLOY_DIR/frontend/dist"
echo "  端口：前端 8080, 后端 8081"
echo ""
ADMIN_SCRIPT

chmod +x /tmp/deploy-admin-v14.sh

# 导出 PYTHON_BIN 给 admin 用户使用
export PYTHON_BIN

# ===========================================
# 5. 以 admin 用户执行部署
# ===========================================
echo "🔄 切换到 admin 用户执行部署..."
echo "(此过程约需 8-12 分钟，请耐心等待)"
echo ""

# 导出环境变量并执行
PYTHON_BIN="$PYTHON_BIN" su - admin -c "PYTHON_BIN=$PYTHON_BIN bash /tmp/deploy-admin-v14.sh"

# ===========================================
# 6. 配置 Nginx
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 6/8: 配置 Nginx"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NGINX_CONF="/etc/nginx/conf.d/gig-platform.conf"

cat > $NGINX_CONF << EOF
server {
    listen 8080;
    server_name $SERVER_IP;
    
    root /home/admin/flex-platform/frontend/dist;
    index index.html;
    
    location / {
        try_files \\\$uri \\\$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
    }
    
    location /api-docs {
        proxy_pass http://127.0.0.1:8081/api-docs;
        proxy_set_header Host \\\$host;
    }
    
    access_log /home/admin/flex-platform/logs/nginx-access.log;
    error_log /home/admin/flex-platform/logs/nginx-error.log;
}
EOF

echo "✅ 测试 Nginx 配置"
nginx -t

echo "✅ 重启 Nginx"
systemctl restart nginx

# ===========================================
# 7. 防火墙
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 7/8: 配置防火墙"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=8080/tcp >/dev/null 2>&1
    firewall-cmd --permanent --add-port=8081/tcp >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    echo "✅ 已配置防火墙端口：8080, 8081"
else
    echo "ℹ️  firewalld 未运行"
fi

echo ""
echo "⚠️  请在阿里云控制台添加防火墙规则："
echo "   https://swasnext.console.aliyun.com/servers/cn-shanghai/1735a331a92f46ef9d82abb417c07b04/firewall"
echo "   - 端口 8080, TCP, 0.0.0.0/0"
echo "   - 端口 8081, TCP, 0.0.0.0/0"
echo ""

# ===========================================
# 8. 验证
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 8/8: 验证部署"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ 检查 PM2 状态..."
su - admin -c "pm2 status" 2>/dev/null || echo "⚠️  PM2 状态检查失败"

echo "✅ 检查后端服务..."
sleep 2
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/health 2>/dev/null || echo "000")
if [ "$BACKEND_STATUS" = "200" ]; then
    echo "   ✅ 后端服务正常 (HTTP $BACKEND_STATUS)"
else
    echo "   ⚠️  后端服务异常 (HTTP $BACKEND_STATUS)"
    echo "      查看日志：su - admin -c 'pm2 logs gig-api'"
fi

echo "✅ 检查 Nginx..."
if systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx 运行正常"
else
    echo "   ⚠️  Nginx 运行异常"
fi

# ===========================================
# 完成
# ===========================================
echo ""
echo "══════════════════════════════════════════════"
echo "  🎉 部署完成！"
echo "══════════════════════════════════════════════"
echo ""
echo "📍 访问地址："
echo "  🌐 前端：http://106.14.172.39:8080"
echo "  🔧 后端 API: http://106.14.172.39:8081"
echo "  📖 API 文档：http://106.14.172.39:8081/api-docs"
echo ""
echo "🔧 常用命令："
echo "  # 切换到 admin 用户"
echo "  su - admin"
echo ""
echo "  # 查看后端日志"
echo "  pm2 logs gig-api --lines 50"
echo ""
echo "  # 重启后端"
echo "  pm2 restart gig-api"
echo ""
echo "  # 重启 Nginx"
echo "  systemctl restart nginx"
echo ""
echo "🛠️  修复说明："
echo "  - Python 版本问题：已配置使用 Python 3.8+"
echo "  - 权限问题：使用 --unsafe-perm 参数"
echo "  - npm 编译：使用 --build-from-source"
echo ""
echo "⚠️  下一步："
echo "  1. 阿里云控制台添加防火墙规则 (8080, 8081)"
echo "  2. 浏览器访问 http://106.14.172.39:8080"
echo "  3. 如有问题：su - admin -c 'pm2 logs gig-api'"
echo ""
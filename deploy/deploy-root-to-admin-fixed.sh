#!/bin/bash
# ===========================================
# 阿里云轻量应用服务器部署脚本
# root 登录版本 - admin 用户部署 - 修复编译问题
# ===========================================

set -e

echo "🚀 =========================================="
echo "   灵活用工平台 - 阿里云部署 (v1.3 修复版)"
echo "========================================== 🚀"
echo ""
echo "服务器：106.14.172.39 (cn-shanghai)"
echo "部署用户：admin"
echo "版本：修复编译问题 v1.3"
echo ""

# 检查是否以 root 运行
if [ "$(whoami)" != "root" ]; then
    echo "⚠️  警告：当前用户不是 root"
    echo "   请使用 root 用户登录后再执行此脚本"
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
# 1. 安装系统依赖和编译工具
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1/7: 安装系统依赖和编译工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ 安装 EPEL 源"
yum install -y epel-release >/dev/null 2>&1 || true

echo "✅ 安装 Node.js 和 npm"
yum install -y nodejs npm >/dev/null 2>&1 || {
    echo "⚠️  尝试使用 NodeSource 安装..."
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    yum install -y nodejs >/dev/null 2>&1
}

echo "✅ 安装编译工具（better-sqlite3 需要）"
yum install -y gcc-c++ python3 make >/dev/null 2>&1 || {
    echo "⚠️  部分编译工具已存在，继续..."
}

echo "✅ 安装 Git 和 Nginx"
yum install -y git nginx >/dev/null 2>&1

echo "✅ 检查 Node.js 版本"
node -v || echo "⚠️  Node.js 可能未正确安装"

echo "✅ 检查 npm 版本"
npm -v || echo "⚠️  npm 可能未正确安装"

echo "✅ 系统依赖安装完成"
echo ""

# ===========================================
# 2. 创建部署目录
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2/7: 创建部署目录"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEPLOY_DIR="/home/admin/flex-platform"

if [ ! -d "$DEPLOY_DIR" ]; then
    echo "✅ 创建部署目录"
    mkdir -p $DEPLOY_DIR/{backend,frontend,logs,pm2}
    chown -R admin:admin $DEPLOY_DIR
else
    echo "ℹ️  部署目录已存在"
fi

# ===========================================
# 3. 准备 admin 用户的部署脚本
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3/7: 准备部署脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat > /tmp/deploy-admin.sh << 'ADMIN_SCRIPT'
#!/bin/bash
set -e

DEPLOY_DIR="/home/admin/flex-platform"
SERVER_IP="106.14.172.39"

echo ""
echo "=========================================="
echo "  以 admin 用户身份执行部署"
echo "=========================================="
echo ""

# 配置 npm 镜像（加速下载）
echo "✅ 配置 npm 淘宝镜像"
npm config set registry https://registry.npmmirror.com

# ===========================================
# 部署后端
# ===========================================
echo ""
echo "━━━ [1/4] 部署后端 ━━━"
cd $DEPLOY_DIR/backend

if [ ! -f "package.json" ]; then
    echo "✅ 拉取后端代码"
    git clone https://github.com/Maoqi-zxy/gig-platform.git .
    git checkout v1.0.0-snapshot
else
    echo "ℹ️  后端代码已存在"
fi

echo "✅ 安装后端依赖（可能需要 3-5 分钟）"
# 清理 npm 缓存
npm cache clean --force 2>/dev/null || true

# 安装依赖（better-sqlite3 需要编译）
npm install --build-from-source --production 2>&1 | tail -20 || {
    echo "⚠️  安装遇到问题，尝试重试..."
    npm install --build-from-source --production 2>&1 | tail -20
}

echo "✅ 配置环境变量"
cat > .env << EOF
NODE_ENV=production
PORT=8081
DATABASE_PATH=$DEPLOY_DIR/backend/gig_platform.db
JWT_SECRET=gig-platform-aliyun-admin-$(date +%Y%m%d%H%M%S)-fixed
CORS_ORIGIN=http://$SERVER_IP:8080
EOF

echo "✅ 安装 PM2"
npm install -g pm2 --registry https://registry.npmmirror.com 2>/dev/null || npm install -g pm2

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
cd $DEPLOY_DIR

MONTH=$(date +%m)
if [ -d "$DEPLOY_DIR/frontend" ]; then
    echo "ℹ️  备份现有前端"
    mv $DEPLOY_DIR/frontend $DEPLOY_DIR/backup_$MONTH
fi

mkdir -p $DEPLOY_DIR/frontend

echo "✅ 拉取前端代码"
rm -rf frontend-temp 2>/dev/null || true
git clone --depth=1 https://github.com/Maoqi-zxy/flexible-work-platform.git frontend-temp
cd frontend-temp

echo "✅ 安装前端依赖"
npm install --silent 2>/dev/null || npm install

echo "✅ 配置 API 地址"
cat > .env.production << EOF
VITE_API_URL=http://$SERVER_IP:8081
EOF

echo "✅ 构建前端（可能需要 2-3 分钟）"
npm run build 2>&1 | tail -10 || {
    echo "⚠️  构建遇到问题"
    npm run build
}

echo "✅ 移动构建产物"
mv dist ../frontend
cd $DEPLOY_DIR
rm -rf frontend-temp

echo "✅ 前端部署完成"

# ===========================================
# 完成
# ===========================================
echo ""
echo "✅ admin 用户部署完成"
echo ""
echo "部署摘要:"
echo "  后端：$DEPLOY_DIR/backend"
echo "  前端：$DEPLOY_DIR/frontend/dist"
echo "  端口：前端 8080, 后端 8081"
echo ""
ADMIN_SCRIPT

chmod +x /tmp/deploy-admin.sh

# ===========================================
# 4. 以 admin 用户执行部署
# ===========================================
echo "🔄 切换到 admin 用户执行部署..."
echo "(此过程约需 5-8 分钟，请耐心等待)"
echo ""

su - admin -c "bash /tmp/deploy-admin.sh"

# ===========================================
# 5. 配置 Nginx
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 5/7: 配置 Nginx"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NGINX_CONF="/etc/nginx/conf.d/gig-platform.conf"

echo "✅ 创建 Nginx 配置"
cat > $NGINX_CONF << EOF
# 灵活用工平台 - 隔离部署（修复版）
server {
    listen 8080;
    server_name $SERVER_IP;
    
    root /home/admin/flex-platform/frontend/dist;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /api-docs {
        proxy_pass http://127.0.0.1:8081/api-docs;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
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
# 6. 配置防火墙
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 6/7: 配置防火墙"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if systemctl is-active --quiet firewalld; then
    echo "✅ 配置 firewalld"
    firewall-cmd --permanent --add-port=8080/tcp >/dev/null 2>&1
    firewall-cmd --permanent --add-port=8081/tcp >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    echo "   已添加端口：8080, 8081"
else
    echo "ℹ️  firewalld 未运行，跳过"
fi

echo ""
echo "⚠️  重要：请在阿里云控制台添加防火墙规则"
echo "   链接：https://swasnext.console.aliyun.com/servers/cn-shanghai/1735a331a92f46ef9d82abb417c07b04/firewall"
echo ""
echo "   添加入站规则："
echo "     - 端口：8080，协议：TCP，授权对象：0.0.0.0/0"
echo "     - 端口：8081，协议：TCP，授权对象：0.0.0.0/0"
echo ""

# ===========================================
# 7. 验证部署
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 7/7: 验证部署"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ 检查后端服务..."
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/health 2>/dev/null || echo "000")
if [ "$BACKEND_STATUS" = "200" ]; then
    echo "   ✅ 后端服务运行正常 (HTTP $BACKEND_STATUS)"
else
    echo "   ⚠️  后端服务响应异常 (HTTP $BACKEND_STATUS)"
    echo "      请稍后检查：su - admin -c 'pm2 logs gig-api'"
fi

echo "✅ 检查前端服务..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null || echo "000")
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "   ✅ 前端服务运行正常 (HTTP $FRONTEND_STATUS)"
else
    echo "   ⚠️  前端服务响应异常 (HTTP $FRONTEND_STATUS)"
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
echo "  🔧 后端：http://106.14.172.39:8081"
echo "  📖 API 文档：http://106.14.172.39:8081/api-docs"
echo ""
echo "🔧 管理命令："
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
echo "⚠️  下一步："
echo "  1. 在阿里云控制台添加防火墙规则（8080, 8081）"
echo "  2. 浏览器访问 http://106.14.172.39:8080 测试"
echo "  3. 如有问题，查看日志：su - admin -c 'pm2 logs gig-api'"
echo ""
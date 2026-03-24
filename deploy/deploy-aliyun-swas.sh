#!/bin/bash
# ===========================================
# 阿里云轻量应用服务器部署脚本
# 隔离部署版 - admin 用户
# ===========================================

set -e

echo "🚀 =========================================="
echo "   灵活用工平台 - 阿里云轻量服务器部署"
echo "========================================== 🚀"
echo ""
echo "服务器：106.14.172.39 (cn-shanghai)"
echo "用户：admin"
echo "版本：隔离部署 v1.1"
echo ""

# 部署目录（admin 用户）
DEPLOY_DIR="/home/admin/flex-platform"

# 检查是否以 admin 用户运行
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "admin" ]; then
    echo "⚠️  警告：当前用户是 $CURRENT_USER，建议使用 admin 用户运行此脚本"
    echo "   如果是 root 用户执行，请使用：su - admin -c 'bash /path/to/deploy.sh'"
    echo ""
fi

# ===========================================
# 1. 检查环境和创建目录
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1/7: 检查环境并创建目录"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$DEPLOY_DIR" ]; then
    echo "✅ 创建部署目录：$DEPLOY_DIR"
    mkdir -p $DEPLOY_DIR/{backend,frontend,nginx,logs,pm2}
    chown -R admin:admin $DEPLOY_DIR
    echo "   所有者：admin:admin"
else
    echo "ℹ️  部署目录已存在：$DEPLOY_DIR"
fi

# ===========================================
# 2. 安装依赖（需要 root 权限）
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2/7: 安装系统依赖（需要 sudo 权限）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查是否需要 sudo
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  使用 sudo 执行安装..."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# 检查 Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo "ℹ️  Node.js 已安装：$NODE_VERSION"
else
    echo "✅ 安装 Node.js"
    $SUDO_CMD yum install -y epel-release
    $SUDO_CMD yum install -y nodejs npm
fi

# 检查 Nginx
if command -v nginx &> /dev/null; then
    echo "ℹ️  Nginx 已安装"
else
    echo "✅ 安装 Nginx"
    $SUDO_CMD yum install -y nginx
fi

# 检查 Git
if command -v git &> /dev/null; then
    echo "ℹ️  Git 已安装"
else
    echo "✅ 安装 Git"
    $SUDO_CMD yum install -y git
fi

# ===========================================
# 3. 部署后端
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3/7: 部署后端服务"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd $DEPLOY_DIR/backend

if [ ! -f "package.json" ]; then
    echo "✅ 拉取后端代码"
    git clone https://github.com/Maoqi-zxy/gig-platform.git .
    git checkout v1.0.0-snapshot
else
    echo "ℹ️  后端代码已存在，跳过拉取"
fi

echo "✅ 安装后端依赖"
npm install --production

echo "✅ 配置环境变量"
cat > .env << EOF
NODE_ENV=production
PORT=8081
DATABASE_PATH=$DEPLOY_DIR/backend/gig_platform.db
JWT_SECRET=gig-platform-aliyun-admin-$(date +%Y%m%d%H%M%S)-isolate
CORS_ORIGIN=http://106.14.172.39:8080
EOF

# ===========================================
# 4. 安装 PM2
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 4/7: 安装 PM2 进程管理"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v pm2 &> /dev/null; then
    echo "ℹ️  PM2 已安装"
else
    echo "✅ 安装 PM2"
    npm install -g pm2
fi

echo "✅ 启动后端服务"
pm2 delete gig-api 2>/dev/null || true
pm2 start --name gig-api npm -- start

echo "✅ 保存 PM2 配置"
pm2 save

echo "✅ 设置 PM2 开机自启"
pm2 startup 2>/dev/null || true

# ===========================================
# 5. 部署前端
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 5/7: 部署前端"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MONTH=$(date +%m)
FRONTEND_BAK="$DEPLOY_DIR/frontend/backup_$MONTH"

if [ -d "$DEPLOY_DIR/frontend" ]; then
    echo "✅ 备份现有前端"
    mv $DEPLOY_DIR/frontend $FRONTEND_BAK
fi

mkdir -p $DEPLOY_DIR/frontend
cd $DEPLOY_DIR

echo "✅ 拉取前端代码"
git clone --depth=1 https://github.com/Maoqi-zxy/flexible-work-platform.git frontend-temp

cd frontend-temp

echo "✅ 安装前端依赖"
npm install

echo "✅ 配置 API 地址"
cat > .env.production << EOF
VITE_API_URL=http://106.14.172.39:8081
EOF

echo "✅ 构建前端"
npm run build

echo "✅ 移动构建产物"
mv dist $DEPLOY_DIR/frontend/dist

# 返回上级目录，清理临时目录
cd $DEPLOY_DIR
rm -rf frontend-temp

echo "✅ 设置权限"
chown -R admin:admin $DEPLOY_DIR/frontend

# 恢复备份配置（可选）
if [ -d "$FRONTEND_BAK" ]; then
    echo "⚠️  旧版本备份在：$FRONTEND_BAK"
    echo "   如需回滚：rm -rf $DEPLOY_DIR/frontend && mv $FRONTEND_BAK $DEPLOY_DIR/frontend"
fi

# ===========================================
# 6. 配置 Nginx
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 6/7: 配置 Nginx"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NGINX_CONF="/etc/nginx/conf.d/gig-platform.conf"
NGINX_CONF_BAK="/etc/nginx/conf.d/gig-platform.conf.bak"

if [ -f "$NGINX_CONF" ]; then
    echo "✅ 备份现有 Nginx 配置"
    cp $NGINX_CONF $NGINX_CONF_BAK
fi

echo "✅ 创建 Nginx 配置"
cat > $NGINX_CONF << 'NGINX_EOF'
# 灵活用工平台 - 隔离部署（admin 用户）
server {
    listen 8080;
    server_name 106.14.172.39;
    
    root /home/admin/flex-platform/frontend/dist;
    index index.html;
    
    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Swagger 文档
    location /api-docs {
        proxy_pass http://127.0.0.1:8081/api-docs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # 日志
    access_log /home/admin/flex-platform/logs/nginx-access.log;
    error_log /home/admin/flex-platform/logs/nginx-error.log;
}
NGINX_EOF

echo "✅ 测试 Nginx 配置"
nginx -t

echo "✅ 重启 Nginx"
systemctl restart nginx

# ===========================================
# 7. 配置防火墙
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 7/7: 配置阿里云防火墙"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 请在阿里云控制台添加防火墙规则（或跳过）："
echo ""
echo "   规则 1:"
echo "     端口：8080"
echo "     协议：TCP"
echo "     授权对象：0.0.0.0/0"
echo ""
echo "   规则 2:"
echo "     端口：8081"
echo "     协议：TCP"
echo "     授权对象：0.0.0.0/0"
echo ""
echo "🔗 控制台链接："
echo "   https://swasnext.console.aliyun.com/servers/cn-shanghai/1735a331a92f46ef9d82abb417c07b04/firewall"
echo ""

read -p "已添加端口？回车确认或输入 y 继续..." FIREWALL_OK

# 尝试配置 firewalld（如果有）
if systemctl is-active --quiet firewalld; then
    echo "✅ 配置 firewalld"
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=8081/tcp
    firewall-cmd --reload
fi

# ===========================================
# 完成
# ===========================================
echo ""
echo "══════════════════════════════════════════════"
echo "  🎉 部署完成！"
echo "══════════════════════════════════════════════"
echo ""
echo "访问地址："
echo "  🌐 前端：http://106.14.172.39:8080"
echo "  🔧 后端：http://106.14.172.39:8081"
echo "  📖 API 文档：http://106.14.172.39:8081/api-docs"
echo ""
echo "管理命令："
echo "  # 查看后端日志"
echo "  pm2 logs gig-api"
echo ""
echo "  # 重启后端"
echo "  pm2 restart gig-api"
echo ""
echo "  # 查看 PM2 状态"
echo "  pm2 status"
echo ""
echo "  # 重启 Nginx"
echo "  systemctl restart nginx"
echo ""
echo "运维说明："
echo "  - 隔离端口：前端 8080，后端 8081"
echo "  - 隔离目录：/home/admin/flex-platform/"
echo "  - 隔离用户：admin"
echo "  - 不影响现有服务（root 用户或其他用户的服务）"
echo ""
echo "运维文档："
echo "  - /home/admin/flex-platform/deploy/阿里云轻量服务器部署方案.md"
echo ""
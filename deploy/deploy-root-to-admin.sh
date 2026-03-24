#!/bin/bash
# ===========================================
# 阿里云轻量应用服务器部署脚本
# root 登录版本 - 自动切换 admin 用户部署
# ===========================================

set -e

echo "🚀 =========================================="
echo "   灵活用工平台 - 阿里云部署 (root→admin)"
echo "========================================== 🚀"
echo ""
echo "服务器：106.14.172.39 (cn-shanghai)"
echo "部署用户：admin"
echo "版本：隔离部署 v1.2 (root 登录)"
echo ""

# 检查是否以 root 运行
if [ "$(whoami)" != "root" ]; then
    echo "⚠️  警告：当前用户不是 root"
    echo "   请使用 root 用户登录后再执行此脚本"
    echo ""
    echo "   或者手动切换到 admin 用户执行："
    echo "   su - admin -c 'bash deploy-root-to-admin.sh'"
    echo ""
    exit 1
fi

# 检查 admin 用户是否存在
if ! id "admin" &>/dev/null; then
    echo "❌ 错误：admin 用户不存在"
    echo "   请先创建 admin 用户或确认用户名正确"
    exit 1
fi

echo "✅ 验证通过：admin 用户存在"
echo ""

# ===========================================
# 1. 安装系统依赖（root 执行）
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1/6: 安装系统依赖（root 权限）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

yum install -y epel-release >/dev/null 2>&1 || true
yum install -y git nodejs npm nginx >/dev/null 2>&1 || {
    echo "⚠️  部分依赖安装失败，继续执行..."
}

echo "✅ 系统依赖安装完成"
echo ""

# ===========================================
# 2. 检查/创建部署目录
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2/6: 检查部署目录"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEPLOY_DIR="/home/admin/flex-platform"

if [ ! -d "$DEPLOY_DIR" ]; then
    echo "✅ 创建部署目录：$DEPLOY_DIR"
    mkdir -p $DEPLOY_DIR/{backend,frontend,logs,pm2}
    chown -R admin:admin $DEPLOY_DIR
    echo "   所有者：admin:admin"
else
    echo "ℹ️  部署目录已存在"
fi

# ===========================================
# 3. 切换到 admin 用户并执行部署
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3/6: 切换到 admin 用户并部署"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 准备部署脚本（admin 用户执行的部分）
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

# 部署后端
echo "━━━ 部署后端 ━━━"
cd $DEPLOY_DIR/backend

if [ ! -f "package.json" ]; then
    echo "✅ 拉取后端代码"
    git clone https://github.com/Maoqi-zxy/gig-platform.git .
    git checkout v1.0.0-snapshot
else
    echo "ℹ️  后端代码已存在"
fi

echo "✅ 安装后端依赖"
npm install --production --silent 2>/dev/null || npm install --production

echo "✅ 配置环境变量"
cat > .env << EOF
NODE_ENV=production
PORT=8081
DATABASE_PATH=$DEPLOY_DIR/backend/gig_platform.db
JWT_SECRET=gig-platform-aliyun-admin-$(date +%Y%m%d%H%M%S)-root
CORS_ORIGIN=http://$SERVER_IP:8080
EOF

echo "✅ 安装 PM2"
npm install -g pm2 --silent 2>/dev/null || npm install -g pm2

echo "✅ 启动后端服务"
pm2 delete gig-api 2>/dev/null || true
pm2 start --name gig-api npm -- start
sleep 2
pm2 save

echo ""
echo "━━━ 部署前端 ━━━"
cd $DEPLOY_DIR

# 备份旧版本
MONTH=$(date +%m)
if [ -d "$DEPLOY_DIR/frontend" ]; then
    echo "✅ 备份现有前端"
    mv $DEPLOY_DIR/frontend $DEPLOY_DIR/backup_$MONTH
fi

mkdir -p $DEPLOY_DIR/frontend

echo "✅ 拉取前端代码"
git clone --depth=1 https://github.com/Maoqi-zxy/flexible-work-platform.git frontend-temp
cd frontend-temp

echo "✅ 安装前端依赖"
npm install --silent 2>/dev/null || npm install

echo "✅ 配置 API 地址"
cat > .env.production << EOF
VITE_API_URL=http://$SERVER_IP:8081
EOF

echo "✅ 构建前端"
npm run build

echo "✅ 移动构建产物"
mv dist ../frontend
cd $DEPLOY_DIR
rm -rf frontend-temp

echo "✅ 设置权限"
echo "(在 admin 用户下，已经是 admin 所有)"

echo ""
echo "✅ admin 用户部署完成"
ADMIN_SCRIPT

chmod +x /tmp/deploy-admin.sh

# 以 admin 用户执行部署
echo "🔄 切换到 admin 用户执行部署..."
su - admin -c "bash /tmp/deploy-admin.sh"

# ===========================================
# 4. 配置 Nginx（root 执行）
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 4/6: 配置 Nginx（root 权限）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NGINX_CONF="/etc/nginx/conf.d/gig-platform.conf"

echo "✅ 创建 Nginx 配置"
cat > $NGINX_CONF << 'EOF'
# 灵活用工平台 - 隔离部署（admin 用户，root 登录版）
server {
    listen 8080;
    server_name 106.14.172.39;
    
    root /home/admin/flex-platform/frontend/dist;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /api-docs {
        proxy_pass http://127.0.0.1:8081/api-docs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
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
# 5. 配置防火墙（如果有 firewalld）
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 5/6: 配置防火墙"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if systemctl is-active --quiet firewalld; then
    echo "✅ 配置 firewalld"
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=8081/tcp
    firewall-cmd --reload
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
# 6. 验证部署
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 6/6: 验证部署"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ 检查后端服务..."
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/health 2>/dev/null || echo "000")
if [ "$BACKEND_STATUS" = "200" ]; then
    echo "   ✅ 后端服务运行正常 (HTTP $BACKEND_STATUS)"
else
    echo "   ⚠️  后端服务响应异常 (HTTP $BACKEND_STATUS)"
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
echo "访问地址："
echo "  🌐 前端：http://106.14.172.39:8080"
echo "  🔧 后端：http://106.14.172.39:8081"
echo "  📖 API 文档：http://106.14.172.39:8081/api-docs"
echo ""
echo "管理命令："
echo "  # 切换到 admin 用户"
echo "  su - admin"
echo ""
echo "  # 查看后端日志（admin 用户）"
echo "  pm2 logs gig-api"
echo ""
echo "  # 重启后端（admin 用户）"
echo "  pm2 restart gig-api"
echo ""
echo "  # 重启 Nginx（root 用户）"
echo "  systemctl restart nginx"
echo ""
echo "隔离说明："
echo "  - 部署用户：admin"
echo "  - 部署目录：/home/admin/flex-platform/"
echo "  - 服务端口：前端 8080，后端 8081"
echo "  - 不影响任何现有服务"
echo ""
echo "下一步："
echo "  1. 在阿里云控制台添加防火墙规则（8080, 8081）"
echo "  2. 浏览器访问 http://106.14.172.39:8080 测试"
echo ""
#!/bin/bash
# ===========================================
# 阿里云部署脚本 - v1.5 最终修复版
# 修复：npm python 配置问题 + Python 版本问题
# ===========================================

set -e

echo "🚀 =========================================="
echo "   灵活用工平台 - 阿里云部署 (v1.5 最终版)"
echo "========================================== 🚀"
echo ""
echo "服务器：106.14.172.39"
echo "版本：最终修复 v1.5"
echo ""

if [ "$(whoami)" != "root" ]; then
    echo "⚠️ 请使用 root 用户登录"
    exit 1
fi

if ! id "admin" &>/dev/null; then
    echo "❌ admin 用户不存在"
    exit 1
fi

echo "✅ 验证通过"
echo ""

# ===========================================
# 1. 安装 Python 3.8+ 和依赖
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1/7: 安装 Python 3.8+ 和编译工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 清理旧的
rm -rf /home/admin/flex-platform/backend/node_modules 2>/dev/null || true
rm -rf /home/admin/flex-platform/backend/package-lock.json 2>/dev/null || true

echo "✅ 安装 EPEL 源"
yum install -y epel-release >/dev/null 2>&1 || true

echo "✅ 安装 IUS 源（获取 Python 3.8+）"
yum install -y https://repo.ius.io/ius-release-el8.rpm >/dev/null 2>&1 || true

echo "✅ 安装 Python 3.8"
yum install -y python38 python38-pip python38-devel >/dev/null 2>&1 || {
    echo "⚠️  尝试安装 python39..."
    yum install -y python39 python39-pip python39-devel >/dev/null 2>&1 || {
        echo "⚠️  使用系统 Python，继续执行..."
    }
}

# 检查 Python 3.8+
if command -v python3.8 &>/dev/null; then
    PYTHON_CMD=python3.8
elif command -v python3.9 &>/dev/null; then
    PYTHON_CMD=python3.9
elif command -v python3 &>/dev/null; then
    # 检查版本是否 >= 3.8
    PY_VER=$(python3 --version 2>&1 | awk '{print $2}')
    if [[ "$PY_VER" > "3.8" ]]; then
        PYTHON_CMD=python3
    else
        echo "⚠️  Python 版本过低 ($PY_VER)，尝试继续..."
        PYTHON_CMD=python3
    fi
else
    PYTHON_CMD=python
fi

echo "✅ 使用 Python: $PYTHON_CMD"
$PYTHON_CMD --version

echo "✅ 安装 Node.js (NodeSource 18.x)"
if ! command -v node &>/dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    yum install -y nodejs >/dev/null 2>&1
else
    echo "ℹ️  Node.js 已安装：$(node -v)"
fi

echo "✅ 安装编译工具"
yum install -y gcc-c++ make git >/dev/null 2>&1

echo "✅ 安装 Nginx"
yum install -y nginx >/dev/null 2>&1 || true

echo ""

# ===========================================
# 2. 准备 admin 部署脚本
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2/7: 准备部署脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEPLOY_DIR="/home/admin/flex-platform"
mkdir -p $DEPLOY_DIR/{backend,frontend,logs,pm2} 2>/dev/null || true
chown -R admin:admin $DEPLOY_DIR 2>/dev/null || true

# 获取 Python 3.8+ 的完整路径
PYTHON_PATH=$(which $PYTHON_CMD 2>/dev/null || echo "/usr/bin/python3")

cat > /tmp/deploy-admin-v15.sh << ADMINSCRIPT
#!/bin/bash
set -e

DEPLOY_DIR="/home/admin/flex-platform"
SERVER_IP="106.14.172.39"
PYTHON_PATH="$PYTHON_PATH"

echo ""
echo "=========================================="
echo "  admin 部署 - 最终修复 v1.5"
echo "=========================================="
echo ""

# ===========================================
# 配置 npm（关键修复）
# ===========================================
echo "✅ 配置 npm"

# 设置淘宝镜像
npm config set registry https://registry.npmmirror.com

# 设置 node-gyp 的 python 路径（使用环境变量）
export PYTHON="$PYTHON_PATH"
export npm_config_python="$PYTHON_PATH"

echo "   Python: \$PYTHON_PATH"
echo "   Node: \$(node -v)"
echo "   npm: \$(npm -v)"
echo ""

# ===========================================
# 部署后端
# ===========================================
echo "━━━ 部署后端 ━━━"
cd \$DEPLOY_DIR/backend

echo "✅ 清理 node_modules"
rm -rf node_modules package-lock.json

if [ ! -f "package.json" ]; then
    echo "✅ 拉取代码"
    git clone https://github.com/Maoqi-zxy/gig-platform.git .
    git checkout v1.0.0-snapshot
fi

echo "✅ 安装依赖 (带编译)"
# 关键：使用环境变量传递 python 路径
npm_config_python="\$PYTHON_PATH" npm install --build-from-source --production --unsafe-perm 2>&1 | tail -30 || {
    echo "⚠️  重试中..."
    npm_config_python="\$PYTHON_PATH" npm install --build-from-source --production --unsafe-perm 2>&1 | tail -30
}

echo "✅ 配置环境变量"
cat > .env << EOF
NODE_ENV=production
PORT=8081
DATABASE_PATH=\$DEPLOY_DIR/backend/gig_platform.db
JWT_SECRET=gig-aliyun-\$(date +%s)-v15
CORS_ORIGIN=http://\$SERVER_IP:8080
EOF

echo "✅ 安装 PM2"
export npm_config_userconfig=\$HOME/.npmrc
npm install -g pm2 --unsafe-perm 2>/dev/null || {
    echo "⚠️  PM2 可能已安装"
}

echo "✅ 启动服务"
pm2 delete gig-api 2>/dev/null || true
pm2 start --name gig-api npm -- start
sleep 3
pm2 save

echo "✅ 后端完成"
echo ""

# ===========================================
# 部署前端
# ===========================================
echo "━━━ 部署前端 ━━━"
cd \$DEPLOY_DIR

MONTH=\$(date +%m)
[ -d "\$DEPLOY_DIR/frontend" ] && mv \$DEPLOY_DIR/frontend \$DEPLOY_DIR/backup_\$MONTH || true
mkdir -p \$DEPLOY_DIR/frontend

echo "✅ 拉取前端"
rm -rf frontend-temp 2>/dev/null || true
git clone --depth=1 https://github.com/Maoqi-zxy/flexible-work-platform.git frontend-temp
cd frontend-temp

echo "✅ 安装依赖"
npm install 2>&1 | tail -5

echo "✅ 配置 API"
cat > .env.production << EOF
VITE_API_URL=http://\$SERVER_IP:8081
EOF

echo "✅ 构建"
npm run build 2>&1 | tail -10

echo "✅ 移动产物"
mv dist ../frontend
cd ..
rm -rf frontend-temp

echo "✅ 前端完成"
echo ""

echo "✅ admin 部署完成"
ADMINSCRIPT

chmod +x /tmp/deploy-admin-v15.sh

# ===========================================
# 3. 执行部署
# ===========================================
echo "🔄 切换 admin 用户部署..."
echo "(等待约 10-15 分钟)"
echo ""

PYTHON_PATH="$PYTHON_PATH" su - admin -c "PYTHON_PATH=$PYTHON_PATH bash /tmp/deploy-admin-v15.sh"

# ===========================================
# 4. Nginx 配置
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 5/7: 配置 Nginx"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat > /etc/nginx/conf.d/gig-platform.conf << EOF
server {
    listen 8080;
    server_name $SERVER_IP;
    root /home/admin/flex-platform/frontend/dist;
    index index.html;
    location / { try_files \\\$uri \\\$uri/ /index.html; }
    location /api { proxy_pass http://127.0.0.1:8081; proxy_set_header Host \\\$host; }
    location /api-docs { proxy_pass http://127.0.0.1:8081/api-docs; }
}
EOF

nginx -t && systemctl restart nginx
echo "✅ Nginx 配置完成"

# ===========================================
# 5. 防火墙
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 6/7: 防火墙"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

systemctl is-active --quiet firewalld && {
    firewall-cmd --permanent --add-port=8080/tcp >/dev/null
    firewall-cmd --permanent --add-port=8081/tcp >/dev/null
    firewall-cmd --reload >/dev/null
    echo "✅ firewalld 配置完成"
} || echo "ℹ️  firewalld 未运行"

echo ""
echo "⚠️  阿里云控制台添加防火墙规则："
echo "   8080/tcp, 8081/tcp, 0.0.0.0/0"

# ===========================================
# 6. 验证
# ===========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 7/7: 验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sleep 2
echo "✅ PM2 状态:"
su - admin -c "pm2 status" || true

echo ""
echo "✅ 后端检查:"
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8081/api/health || echo "失败"

echo "✅ 前端检查:"
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/ || echo "失败"

echo "✅ Nginx:"
systemctl is-active nginx >/dev/null && echo "运行中" || echo "异常"

# ===========================================
# 完成
# ===========================================
echo ""
echo "══════════════════════════════════════════"
echo "  🎉 部署完成！"
echo "══════════════════════════════════════════"
echo ""
echo "访问："
echo "  http://106.14.172.39:8080"
echo ""
echo "管理:"
echo "  su - admin"
echo "  pm2 logs gig-api"
echo "  pm2 restart gig-api"
echo ""
#!/bin/bash
# ===========================================
# 灵活用工平台 - 前端快速修复脚本 (备用方案)
# 解决：GitHub 访问失败问题
# ===========================================

set -e

echo "🚀 =========================================="
echo "   前端修复脚本 - 备用方案"
echo "========================================== 🚀"
echo ""

SERVER_IP="106.14.172.39"
DEPLOY_DIR="/home/admin/flex-platform"

# ===========================================
# 使用本地已有代码或下载 zip
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "方案：使用本地代码/离线包"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 方法 1: 使用已存在的后端目录中的前端代码（如果有）
if [ -d "$DEPLOY_DIR/frontend-code" ]; then
    echo "✅ 发现已有前端代码副本"
    cd $DEPLOY_DIR/frontend-code
elif [ -d "/home/admin/flex-platform/frontend-temp" ]; then
    echo "✅ 使用已存在的前端临时目录"
    cd /home/admin/flex-platform/frontend-temp
else
    echo "⚠️  尝试使用备用方式获取代码..."
    
    # 方法 2: 下载到 /tmp 目录
    cd /tmp
    rm -rf flexible-work-platform-main
    rm -rf flexible-work-platform.zip
    
    echo "   尝试下载 GitHub ZIP 包..."
    # 使用 GitHub 的 zip 下载链接（不需要 git）
    curl -L -o flexible-work-platform.zip \
        "https://github.com/Maoqi-zxy/flexible-work-platform/archive/refs/heads/main.zip" \
        --connect-timeout 10 \
        --max-time 60 \
        2>&1 | tail -5
    
    if [ -f "flexible-work-platform.zip" ]; then
        echo "   解压代码包..."
        unzip -o flexible-work-platform.zip >/dev/null 2>&1
        cd flexible-work-platform-main
        echo "✅ 代码解压完成"
        ls -la
    else
        echo "❌ 下载失败，尝试其他方式..."
        echo ""
        echo "请手动执行以下命令："
        echo ""
        echo "  cd /home/admin/flex-platform"
        echo "  git clone https://gitee.com/alternatives/flexible-work-platform.git frontend-code"
        echo "  # 或者手动上传代码包"
        exit 1
    fi
fi

echo ""

# ===========================================
# 安装依赖和构建
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "构建前端"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ 配置 npm"
npm config set registry https://registry.npmmirror.com

echo "✅ 安装依赖（约 2-3 分钟）"
npm install 2>&1 | tail -10

echo "✅ 配置 API 地址"
cat > .env.production << EOF
VITE_API_URL=http://$SERVER_IP:8080
EOF

echo "✅ 构建前端（约 2-3 分钟）"
npm run build 2>&1 | tail -15

# 检查构建结果
if [ -d "dist" ] && [ -f "dist/index.html" ]; then
    echo "✅ 构建成功"
else
    echo "❌ 构建失败"
    ls -la
    exit 1
fi

echo ""

# ===========================================
# 移动到部署目录
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "部署前端文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd /home/admin/flex-platform

# 清理旧的前端目录
if [ -d "frontend" ]; then
    echo "ℹ️  备份旧前端"
    mv frontend frontend_$(date +%Y%m%d_%H%M%S)
fi

# 移动新构建的文件
echo "✅ 移动构建产物"
mkdir -p frontend
# 确保从正确的源目录复制
if [ -d "/tmp/flexible-work-platform-main/dist" ]; then
    cp -r /tmp/flexible-work-platform-main/dist/* frontend/
elif [ -d "./dist" ]; then
    cp -r dist/* frontend/
else
    echo "❌ 找不到 dist 目录"
    find . -name "dist" -type d 2>/dev/null
    find /tmp -name "dist" -type d 2>/dev/null | head -5
    exit 1
fi

echo "✅ 验证文件"
ls -la frontend/ | head -15

echo ""

# ===========================================
# 配置 Nginx
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "配置 Nginx"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 选择端口
FRONTEND_PORT=8080
if netstat -tlnp 2>/dev/null | grep -q ":8080.*searxng"; then
    echo "⚠️  8080 被 searxng 占用，使用 8082"
    FRONTEND_PORT=8082
fi

cat > /etc/nginx/conf.d/gig-platform.conf << NGINXCFG
server {
    listen $FRONTEND_PORT;
    server_name $SERVER_IP;
    
    root /home/admin/flex-platform/frontend;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /api-docs {
        proxy_pass http://127.0.0.1:8081/api-docs;
    }
}
NGINXCFG

echo "✅ 测试 Nginx 配置"
nginx -t

echo "✅ 重启 Nginx"
systemctl restart nginx

echo ""

# ===========================================
# 验证
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "验证部署"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sleep 2

echo "服务状态:"
echo "  Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'inactive')"
echo "  前端端口：$FRONTEND_PORT"
echo ""
echo "HTTP 检查:"
echo "  前端：$(curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:$FRONTEND_PORT/ 2>/dev/null || echo '失败')"
echo "  后端：$(curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:8081/api/health 2>/dev/null || echo '失败')"

echo ""
echo "══════════════════════════════════════════"
echo "  ✅ 修复完成！"
echo "══════════════════════════════════════════"
echo ""
echo "访问地址："
echo "  http://$SERVER_IP:$FRONTEND_PORT"
echo ""
echo "Nginx 状态:"
echo "  systemctl status nginx"
echo ""
echo "如果仍然失败："
echo "  cat /var/log/nginx/error.log"
echo ""
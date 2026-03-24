#!/bin/bash
# ===========================================
# 灵活用工平台 - 阿里云服务器完整修复脚本
# 修复问题：Nginx 未运行 + 前端未构建 + 端口冲突
# ===========================================

set -e

echo "🚀 =========================================="
echo "   灵活用工平台 - 完整修复脚本 v1.0"
echo "========================================== 🚀"
echo ""
echo "服务器：106.14.172.39"
echo "时间：$(date)"
echo ""

SERVER_IP="106.14.172.39"
FRONTEND_PORT=8082  # 避免与 searxng 的 8080 冲突

# ===========================================
# 检查问题
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1/6: 检查当前状态"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ Nginx 状态：$(systemctl is-active nginx 2>/dev/null || echo 'inactive')"
echo "✅ 8080 端口占用：$(netstat -tlnp 2>/dev/null | grep ':8080' | awk '{print $NF}' || echo '无')"
echo "✅ PM2 状态：$(su - admin -c 'pm2 status' 2>/dev/null | grep gig-api | awk '{print $5}' || echo '未知')"

# 检查前端目录
if [ -f "/home/admin/flex-platform/frontend/dist/index.html" ]; then
    echo "✅ 前端构建：已存在"
    FRONTEND_EXISTS=true
else
    echo "⚠️  前端构建：不存在"
    FRONTEND_EXISTS=false
fi

echo ""

# ===========================================
# 停止 searxng（释放 8080 端口）
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2/6: 处理端口冲突"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查 searxng 是否在运行
if pgrep -x "searxng" >/dev/null 2>&1; then
    echo "⚠️  检测到 searxng 占用 8080 端口"
    echo ""
    echo "请选择处理方式："
    echo "  1) 停止 searxng（推荐，如果你不需要它）"
    echo "  2) 使用其他端口（8082）部署前端"
    echo ""
    read -p "请选择 (1/2)，默认 2: " PORT_CHOICE
    
    if [ "$PORT_CHOICE" = "1" ]; then
        echo "✅ 停止 searxng..."
        pkill -x searxng || true
        systemctl stop searxng 2>/dev/null || true
        systemctl disable searxng 2>/dev/null || true
        echo "   searxng 已停止"
        FRONTEND_PORT=8080
    else
        echo "✅ 使用端口 8082 部署前端"
        FRONTEND_PORT=8082
    fi
else
    echo "✅ 8080 端口可用"
    FRONTEND_PORT=8080
fi

echo ""

# ===========================================
# 构建前端
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3/6: 构建前端"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$FRONTEND_EXISTS" = true ]; then
    echo "ℹ️  前端已存在，跳过构建"
else
    echo "✅ 切换到 admin 用户构建前端..."
    
    su - admin << ADMINBUILD

echo "   配置 npm..."
npm config set registry https://registry.npmmirror.com
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
export PATH=~/.npm-global/bin:$PATH

echo "   进入部署目录..."
cd /home/admin/flex-platform

# 清理旧的前端
rm -rf frontend frontend-temp 2>/dev/null || true

echo "   拉取前端代码..."
git clone --depth=1 https://github.com/Maoqi-zxy/flexible-work-platform.git frontend-temp
cd frontend-temp

echo "   安装依赖..."
npm install 2>&1 | tail -5

echo "   配置 API 地址..."
cat > .env.production << ENVFILE
VITE_API_URL=http://$SERVER_IP:$FRONTEND_PORT
ENVFILE

echo "   构建前端（约 2-3 分钟）..."
npm run build 2>&1 | tail -10

echo "   移动构建产物..."
mv dist ../frontend
cd ..
rm -rf frontend-temp

echo "   验证构建..."
ls -la frontend/dist/ | head -10

echo "✅ 前端构建完成"
ADMINBUILD
    
    # 确认前端文件存在
    if [ -f "/home/admin/flex-platform/frontend/dist/index.html" ]; then
        echo "✅ 前端构建成功"
    else
        echo "❌ 前端构建失败"
        exit 1
    fi
fi

echo ""

# ===========================================
# 配置 Nginx
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 4/6: 配置 Nginx"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 备份现有配置
if [ -f "/etc/nginx/conf.d/gig-platform.conf" ]; then
    echo "✅ 备份现有配置"
    cp /etc/nginx/conf.d/gig-platform.conf /etc/nginx/conf.d/gig-platform.conf.bak
fi

# 创建 Nginx 配置
echo "✅ 创建 Nginx 配置"
cat > /etc/nginx/conf.d/gig-platform.conf << NGINXCFG
# 灵活用工平台 - Nginx 配置
# 生成时间：$(date)

server {
    listen $FRONTEND_PORT;
    server_name $SERVER_IP;
    
    # 前端静态文件
    root /home/admin/flex-platform/frontend/dist;
    index index.html;
    
    # SPA 路由支持
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # API 文档
    location /api-docs {
        proxy_pass http://127.0.0.1:8081/api-docs;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Swagger 静态资源
    location /swagger-ui {
        proxy_pass http://127.0.0.1:8081/swagger-ui;
        proxy_set_header Host \$host;
    }
    
    # 日志
    access_log /home/admin/flex-platform/logs/nginx-access.log;
    error_log /home/admin/flex-platform/logs/nginx-error.log;
    
    # 客户端请求大小限制
    client_max_body_size 10M;
}
NGINXCFG

echo "✅ 测试 Nginx 配置"
if nginx -t 2>&1 | grep -q "successful"; then
    echo "   配置测试通过"
else
    echo "⚠️  配置测试警告："
    nginx -t 2>&1 | tail -5
fi

echo ""

# ===========================================
# 启动 Nginx
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 5/6: 启动 Nginx"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 启用并启动 Nginx
echo "✅ 启用 Nginx 开机自启"
systemctl enable nginx

echo "✅ 启动 Nginx"
systemctl restart nginx

# 检查 Nginx 状态
if systemctl is-active nginx >/dev/null 2>&1; then
    echo "✅ Nginx 运行正常"
else
    echo "⚠️  Nginx 启动失败，尝试重新加载..."
    systemctl reload nginx 2>/dev/null || true
fi

echo ""

# ===========================================
# 验证部署
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 6/6: 验证部署"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sleep 2

echo "服务状态检查："
echo ""

# Nginx 状态
echo "  Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'inactive')"

# PM2 状态
PM2_STATUS=$(su - admin -c "pm2 status gig-api 2>/dev/null | grep gig-api | awk '{print \$5}'" || echo "unknown")
echo "  后端 PM2: $PM2_STATUS"

# 前端文件
if [ -f "/home/admin/flex-platform/frontend/dist/index.html" ]; then
    echo "  前端文件: ✅ 存在"
else
    echo "  前端文件: ❌ 不存在"
fi

echo ""
echo "HTTP 状态检查："
echo ""

# 本地访问测试
echo "  本地前端：$(curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:$FRONTEND_PORT/ 2>/dev/null || echo '失败')"
echo "  本地后端：$(curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:8081/api/health 2>/dev/null || echo '失败')"
echo "  本地 API 文档：$(curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:8081/api-docs/ 2>/dev/null || echo '失败')"

echo ""
echo "公网访问地址："
echo ""
echo "  🌐 前端：http://$SERVER_IP:$FRONTEND_PORT"
echo "  🔧 后端 API: http://$SERVER_IP:8081"
echo "  📖 API 文档：http://$SERVER_IP:8081/api-docs/"

echo ""

# ===========================================
# 防火墙提示
# ===========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  重要：配置阿里云防火墙"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "请在阿里云控制台添加防火墙规则："
echo ""
echo "  链接：https://swasnext.console.aliyun.com/servers/cn-shanghai/1735a331a92f46ef9d82abb417c07b04/firewall"
echo ""
echo "  添加入站规则："
echo "    - 端口：$FRONTEND_PORT，协议：TCP，授权对象：0.0.0.0/0"
echo "    - 端口：8081，协议：TCP，授权对象：0.0.0.0/0"
echo ""

# ===========================================
# 完成
# ===========================================
echo "══════════════════════════════════════════════"
echo "  🎉 修复完成！"
echo "══════════════════════════════════════════════"
echo ""
echo "📍 访问地址："
echo "  前端：http://$SERVER_IP:$FRONTEND_PORT"
echo "  API: http://$SERVER_IP:8081"
echo "  文档：http://$SERVER_IP:8081/api-docs/"
echo ""
echo "🔧 常用命令："
echo ""
echo "  # 查看后端日志"
echo "  su - admin -c 'pm2 logs gig-api'"
echo ""
echo "  # 重启后端"
echo "  su - admin -c 'pm2 restart gig-api'"
echo ""
echo "  # 重启 Nginx"
echo "  sudo systemctl restart nginx"
echo ""
echo "  # 查看 Nginx 状态"
echo "  systemctl status nginx"
echo ""
echo "📋 修复摘要："
echo "  - 处理 searxng 端口冲突（使用端口 $FRONTEND_PORT）"
echo "  - 构建前端静态文件"
echo "  - 配置 Nginx 反向代理"
echo "  - 启动 Nginx 服务"
echo ""
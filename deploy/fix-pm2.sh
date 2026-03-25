#!/bin/bash
# ===========================================
# PM2 修复脚本 - 快速修复
# ===========================================

echo "🔧 修复 PM2 安装..."
echo ""

# 切换到 admin 用户
su - admin << 'ADMINFIX'

echo "✅ 配置 npm 镜像"
npm config set registry https://registry.npmmirror.com

echo "✅ 创建用户级 npm 目录"
mkdir -p ~/.npm-global

echo "✅ 配置 npm 使用用户目录"
npm config set prefix '~/.npm-global'

echo "✅ 添加到 PATH"
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

echo "✅ 安装 PM2"
npm install -g pm2 2>&1 | tail -10

echo "✅ 验证 PM2"
pm2 --version

echo "✅ 启动应用"
cd /home/admin/flex-platform/backend

# 检查 node_modules 是否存在
if [ ! -d "node_modules" ]; then
    echo "⚠️  node_modules 不存在，重新安装..."
    npm install --omit=dev
fi

# 删除旧的 PM2 进程
pm2 delete gig-api 2>/dev/null || true

# 启动服务
pm2 start npm --name gig-api -- start

sleep 3

echo "✅ 保存 PM2 配置"
pm2 save

echo "✅ PM2 状态"
pm2 status

ADMINFIX

echo ""
echo "✅ PM2 修复完成！"
echo ""
echo "验证命令："
echo "  su - admin -c 'pm2 status'"
echo "  curl http://localhost:8081/api/health"
#!/bin/bash
# ===========================================
# 快速配置向导 - 5 分钟完成部署配置
# ===========================================

set -e

echo "🚀 =========================================="
echo "   灵活用工平台 - 快速开始"
echo "========================================== 🚀"
echo ""
echo "本向导将在 5 分钟内帮助您完成:"
echo "  1. 数据库配置 (MongoDB Atlas 或 SQLite)"
echo "  2. 环境变量设置"
echo "  3. 部署验证"
echo ""
read -p "按回车键继续..."

# 步骤 1: 选择数据库
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1/4: 选择数据库类型"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1) MongoDB Atlas (推荐 - 生产环境)"
echo "   • 免费 M0 集群"
echo "   • 自动备份"
echo "   • 高可用性"
echo ""
echo "2) SQLite (快速测试 - 开发环境)"
echo "   • 零配置"
echo "   • 单文件数据库"
echo "   • 不适合生产"
echo ""
read -p "请选择 (1/2): " DB_CHOICE

if [ "$DB_CHOICE" = "2" ]; then
    echo ""
    echo "✅ 已选择: SQLite"
    echo ""
    echo "下一步：直接配置环境变量"
else
    echo ""
    echo "📊 接下来需要创建 MongoDB Atlas 集群:"
    echo ""
    echo "打开浏览器访问:"
    echo "  👉 https://cloud.mongodb.com"
    echo ""
    read -p "按回车键打开浏览器 (请手动创建集群后返回)..."
    
    # 尝试打开浏览器
    if command -v open &> /dev/null; then
        open https://cloud.mongodb.com
    elif command -v xdg-open &> /dev/null; then
        xdg-open https://cloud.mongodb.com
    else
        echo "请手动打开：https://cloud.mongodb.com"
    fi
    
    echo ""
    echo "📋 MongoDB Atlas 创建步骤:"
    echo "   1. 注册/登录账号"
    echo "   2. 点击 'Build a Database'"
    echo "   3. 选择 'M0 FREE' 套餐"
    echo "   4. 选择区域 (建议：AWS Tokyo)"
    echo "   5. 集群名：flex-gig-cluster"
    echo "   6. 等待创建完成"
    echo ""
    echo "   7. Database Access → 创建用户"
    echo "      用户名：flexgig_admin"
    echo "      权限：Read and write"
    echo ""
    echo "   8. Network Access → 添加 IP"
    echo "      选择：Allow Access from Anywhere (0.0.0.0/0)"
    echo ""
    echo "   9. Database → Connect → Connect your application"
    echo "      复制连接字符串"
    echo ""
    read -p "完成后按回车键继续..."
fi

# 步骤 2: 配置环境变量
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2/4: 配置环境变量"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 生成 JWT 密钥
JWT_SECRET=$(openssl rand -hex 32)
echo "✅ 已生成 JWT 密钥"
echo ""

# 输入数据库连接
if [ "$DB_CHOICE" != "2" ]; then
    echo "请输入 MongoDB 连接字符串:"
    echo "(格式：mongodb+srv://flexgig_admin:****@cluster.mongodb.net/flex-gig?retryWrites=true&w=majority)"
    read -p "MONGODB_URI: " MONGODB_URI
fi

# 创建 .env.local
cat > .env.local << EOF
# 灵活用工平台 - 环境变量
NODE_ENV=production
PORT=3000
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=7d
CORS_ORIGIN=https://flex-gig-platform.vercel.app
LOG_LEVEL=info
EOF

if [ "$DB_CHOICE" = "2" ]; then
    echo "USE_SQLITE=true" >> .env.local
    echo "DATABASE_URL=sqlite://./data/flex-gig.db" >> .env.local
    echo -e "\n✅ 已配置: SQLite"
else
    echo "MONGODB_URI=${MONGODB_URI}" >> .env.local
    echo -e "\n✅ 已配置: MongoDB Atlas"
fi

echo "✅ 已创建: .env.local"

# 添加 .gitignore
if ! grep -q ".env.local" ../.gitignore 2>/dev/null; then
    echo ".env.local" >> ../.gitignore
    echo "✅ 已添加到 .gitignore"
fi

# 步骤 3: 设置 Railway
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3/4: 配置 Railway"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v railway &> /dev/null; then
    read -p "是否使用 Railway CLI 设置环境变量？(y/n): " USE_CLI
    
    if [ "$USE_CLI" = "y" ]; then
        echo "正在登录 Railway..."
        railway login
        
        echo ""
        echo "设置环境变量..."
        railway variables set NODE_ENV=production
        railway variables set PORT=3000
        railway variables set JWT_SECRET="$JWT_SECRET"
        railway variables set CORS_ORIGIN="https://flex-gig-platform.vercel.app"
        
        if [ "$DB_CHOICE" = "2" ]; then
            railway variables set USE_SQLITE=true
            railway variables set DATABASE_URL=sqlite://./data/flex-gig.db
        else
            railway variables set MONGODB_URI="$MONGODB_URI"
        fi
        
        echo "✅ Railway 环境变量设置完成"
    else
        echo "请手动在 Railway Dashboard 设置:"
        echo "  👉 https://railway.app/dashboard"
        echo ""
        echo "需要在 Variables 中设置:"
        echo "  - NODE_ENV = production"
        echo "  - PORT = 3000"
        echo "  - JWT_SECRET = $JWT_SECRET"
        echo "  - CORS_ORIGIN = https://flex-gig-platform.vercel.app"
        if [ "$DB_CHOICE" != "2" ]; then
            echo "  - MONGODB_URI = (你的连接字符串)"
        else
            echo "  - USE_SQLITE = true"
            echo "  - DATABASE_URL = sqlite://./data/flex-gig.db"
        fi
        
        read -p "完成后按回车键继续..."
    fi
else
    echo "⚠️  未安装 Railway CLI"
    echo ""
    echo "安装命令: npm install -g @railway/cli"
    echo ""
    echo "或访问 Dashboard 手动设置:"
    echo "  👉 https://railway.app/dashboard"
    read -p "完成后按回车键继续..."
fi

# 步骤 4: 设置 Vercel
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 4/4: 配置 Vercel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v vercel &> /dev/null; then
    read -p "是否使用 Vercel CLI 设置环境变量？(y/n): " USE_VERCEL_CLI
    
    if [ "$USE_VERCEL_CLI" = "y" ]; then
        echo "设置环境变量..."
        echo "NEXT_PUBLIC_API_URL=https://flex-gig-api.railway.app" | vercel env add -
        echo "NEXT_PUBLIC_ENV=production" | vercel env add -
        echo "✅ Vercel 环境变量设置完成"
    else
        echo "请手动在 Vercel Dashboard 设置:"
        echo "  👉 https://vercel.com/dashboard"
        echo ""
        echo "需要在 Environment Variables 中设置:"
        echo "  - NEXT_PUBLIC_API_URL = https://flex-gig-api.railway.app"
        echo "  - NEXT_PUBLIC_ENV = production"
        
        read -p "完成后按回车键继续..."
    fi
else
    echo "⚠️  未安装 Vercel CLI"
    echo ""
    echo "安装命令: npm install -g vercel"
    echo ""
    echo "或访问 Dashboard 手动设置:"
    echo "  👉 https://vercel.com/dashboard"
    read -p "完成后按回车键继续..."
fi

# 完成
echo ""
echo "🎉 =========================================="
echo "   配置完成!"
echo "========================================== 🎉"
echo ""
echo "📋 下一步操作:"
echo ""
echo "  1. 部署后端到 Railway:"
echo "     cd backend && railway up --prod"
echo ""
echo "  2. 部署前端到 Vercel:"
echo "     cd frontend && vercel --prod"
echo ""
echo "  3. 验证部署:"
echo "     ./verify-deployment.sh"
echo ""
echo "  4. 查看日志:"
echo "     Railway: railway logs"
echo "     Vercel:  vercel logs"
echo ""
echo "🌐 访问地址:"
echo "   前端：https://flex-gig-platform.vercel.app"
echo "   后端：https://flex-gig-api.railway.app"
echo ""
echo "📚 更多文档:"
echo "   - 环境配置：cat ENVIRONMENT_CONFIG.md"
echo "   - 部署清单：cat CHECKLIST.md"
echo "   - 状态报告：cat DEPLOYMENT_STATUS.md"
echo ""
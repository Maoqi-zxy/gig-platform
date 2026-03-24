#!/bin/bash
# ===========================================
# 环境变量配置脚本
# ===========================================
# 用途：自动设置 Railway 和 Vercel 的环境变量
# 用法：./setup-env.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔑 灵活用工平台 - 环境变量配置"
echo "==========================================${NC}"

# 生成 JWT 密钥
JWT_SECRET=$(openssl rand -hex 32)
echo -e "${GREEN}✓ 生成 JWT 密钥：${JWT_SECRET:0:16}...${NC}"

# 交互式输入数据库配置
echo -e "\n${YELLOW}📊 数据库配置${NC}"
echo "=========================================="
echo ""
echo "选择数据库类型:"
echo "1) MongoDB Atlas (推荐用于生产)"
echo "2) SQLite (快速测试)"
echo ""
read -p "请输入选择 (1/2): " DB_CHOICE

if [ "$DB_CHOICE" = "2" ]; then
    USE_SQLITE="true"
    MONGODB_URI=""
    echo -e "${GREEN}✓ 选择：SQLite${NC}"
else
    USE_SQLITE="false"
    echo ""
    echo -e "${YELLOW}请输入 MongoDB 连接字符串:${NC}"
    echo "格式：mongodb+srv://<user>:<password>@cluster.mongodb.net/<db>?retryWrites=true&w=majority"
    echo ""
    read -p "MONGODB_URI: " MONGODB_URI
    
    if [ -z "$MONGODB_URI" ]; then
        echo -e "${RED}✗ 错误：MongoDB 连接字符串不能为空${NC}"
        exit 1
    fi
    
    # 脱敏显示
    DB_DISPLAY=$(echo "$MONGODB_URI" | sed 's/:\/\/[^:]*:/\/\/***:/g')
    echo -e "${GREEN}✓ 数据库连接：${DB_DISPLAY}${NC}"
fi

# 确认域名
echo ""
echo -e "${YELLOW}🌐 确认部署域名${NC}"
echo "=========================================="
read -p "前端域名 [flex-gig-platform.vercel.app]: " FRONTEND_DOMAIN
FRONTEND_DOMAIN=${FRONTEND_DOMAIN:-flex-gig-platform.vercel.app}

read -p "后端域名 [flex-gig-api.railway.app]: " BACKEND_DOMAIN
BACKEND_DOMAIN=${BACKEND_DOMAIN:-flex-gig-api.railway.app}

echo ""
echo -e "${GREEN}前端：https://${FRONTEND_DOMAIN}${NC}"
echo -e "${GREEN}后端：https://${BACKEND_DOMAIN}${NC}"

# 创建本地 .env 文件
echo -e "\n${YELLOW}📁 创建本地配置文件${NC}"
echo "=========================================="

cat > .env.local << EOF
# ===========================================
# 灵活用工平台 - 环境变量配置
# ===========================================
# 生成时间：$(date -Iseconds)
# ⚠️ 切勿将此文件提交到 Git!

# 前端环境变量 (Vercel)
NEXT_PUBLIC_API_URL=https://${BACKEND_DOMAIN}
NEXT_PUBLIC_ENV=production

# 后端环境变量 (Railway)
NODE_ENV=production
PORT=3000
EOF

if [ "$USE_SQLITE" = "true" ]; then
    cat >> .env.local << EOF
USE_SQLITE=true
DATABASE_URL=sqlite://./data/flex-gig.db
EOF
else
    cat >> .env.local << EOF
MONGODB_URI=${MONGODB_URI}
EOF
fi

cat >> .env.local << EOF
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=7d
CORS_ORIGIN=https://${FRONTEND_DOMAIN}
LOG_LEVEL=info
EOF

echo -e "${GREEN}✓ 创建 .env.local 文件${NC}"
echo -e "${YELLOW}⚠️  已将 .env.local 添加到 .gitignore${NC}"

# 检查是否已添加到 .gitignore
if ! grep -q ".env.local" ../.gitignore 2>/dev/null; then
    echo ".env.local" >> ../.gitignore
    echo -e "${GREEN}✓ 已更新 .gitignore${NC}"
fi

# Railway 配置
echo -e "\n${YELLOW}🚂 配置 Railway 环境变量${NC}"
echo "=========================================="
echo ""

if command -v railway &> /dev/null; then
    echo -e "${BLUE}检测到 Railway CLI${NC}"
    read -p "是否现在设置 Railway 环境变量？(y/n): " SET_RAILWAY
    
    if [ "$SET_RAILWAY" = "y" ]; then
        echo "登录 Railway..."
        railway login
        
        echo "设置环境变量..."
        railway variables set NODE_ENV=production
        railway variables set PORT=3000
        
        if [ "$USE_SQLITE" = "true" ]; then
            railway variables set USE_SQLITE=true
            railway variables set DATABASE_URL=sqlite://./data/flex-gig.db
        else
            railway variables set MONGODB_URI="$MONGODB_URI"
        fi
        
        railway variables set JWT_SECRET="$JWT_SECRET"
        railway variables set JWT_EXPIRES_IN=7d
        railway variables set CORS_ORIGIN="https://${FRONTEND_DOMAIN}"
        railway variables set LOG_LEVEL=info
        
        echo -e "${GREEN}✓ Railway 环境变量设置完成${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  未安装 Railway CLI${NC}"
    echo "手动安装：npm install -g @railway/cli"
    echo "或使用 Railway Dashboard 手动设置"
fi

# Vercel 配置
echo -e "\n🎨 配置 Vercel 环境变量"
echo "=========================================="
echo ""

if command -v vercel &> /dev/null; then
    echo -e "${BLUE}检测到 Vercel CLI${NC}"
    read -p "是否现在设置 Vercel 环境变量？(y/n): " SET_VERCEL
    
    if [ "$SET_VERCEL" = "y" ]; then
        echo "设置环境变量..."
        echo "NEXT_PUBLIC_API_URL=https://${BACKEND_DOMAIN}" | vercel env add -
        echo "NEXT_PUBLIC_ENV=production" | vercel env add -
        
        echo -e "${GREEN}✓ Vercel 环境变量设置完成${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  未安装 Vercel CLI${NC}"
    echo "手动安装：npm install -g vercel"
    echo "或使用 Vercel Dashboard 手动设置"
fi

# 显示配置摘要
echo -e "\n${GREEN}=========================================="
echo "✅ 配置完成!"
echo "==========================================${NC}"
echo ""
echo "📋 配置摘要:"
echo "   前端域名：https://${FRONTEND_DOMAIN}"
echo "   后端域名：https://${BACKEND_DOMAIN}"
if [ "$USE_SQLITE" = "true" ]; then
    echo "   数据库：SQLite"
else
    echo "   数据库：MongoDB Atlas (脱敏)"
fi
echo "   JWT 密钥：已生成 (32 字节)"
echo ""
echo "📁 本地配置文件：./.env.local"
echo ""
echo "🚀 下一步:"
echo "   1. cd ../frontend && vercel --prod"
echo "   2. cd ../backend && railway up --prod"
echo "   3. 验证部署：curl https://${BACKEND_DOMAIN}/api/health"
echo ""

# 安全提醒
echo -e "${YELLOW}⚠️  安全提醒:${NC}"
echo "   • 切勿将 .env.local 提交到 Git"
echo "   • 定期更换 JWT 密钥"
echo "   • 使用强数据库密码"
echo ""
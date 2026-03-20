#!/bin/bash
# Gig Platform 自动化部署脚本
# 部署到 Railway

set -e

echo "🚀 开始部署 Gig Platform 到 Railway..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查 Railway CLI 是否安装
if ! command -v railway &> /dev/null; then
    echo -e "${YELLOW}⚠️  Railway CLI 未安装，正在安装...${NC}"
    # 使用 Homebrew 安装 Railway CLI
    if command -v brew &> /dev/null; then
        brew install railway
    else
        echo -e "${RED}❌ 请先安装 Railway CLI: npm install -g @railway/cli${NC}"
        exit 1
    fi
fi

# 检查 Railway 登录状态
if ! railway whoami &> /dev/null; then
    echo -e "${YELLOW}⚠️  未登录 Railway，正在引导登录...${NC}"
    railway login
fi

# 进入项目目录
cd "$(dirname "$0")"

# 检查是否已在 Railway 创建项目
PROJECT_ID=$(railway status --json 2>/dev/null | jq -r '.projectId' 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}📦 创建新的 Railway 项目...${NC}"
    railway init --name gig-platform
fi

# 配置环境变量
echo -e "${YELLOW}⚙️  配置环境变量...${NC}"
railway variables set NODE_ENV=production
railway variables set PORT=3000
railway variables set JWT_SECRET="gig-platform-production-secret-$(date +%s)"
railway variables set CORS_ORIGIN="https://flexible-work-platform.vercel.app"

# 由于 Railway 支持 SQLite，我们可以使用 SQLite 进行快速部署
# 如果需要 MongoDB，请设置 MONGODB_URI
echo -e "${YELLOW}📊 配置数据库 (使用 SQLite 快速部署)...${NC}"
echo "DATABASE_PATH=./gig_platform.db" > .env.production
railway variables set DATABASE_PATH="./gig_platform.db"

# 推送到 Railway
echo -e "${YELLOW}🚀 开始部署...${NC}"
railway up --detach

# 等待部署完成
echo -e "${YELLOW}⏳ 等待部署完成...${NC}"
sleep 10

# 获取部署 URL
DEPLOY_URL=$(railway status --json 2>/dev/null | jq -r '.deployments[0].url' 2>/dev/null || echo "")

if [ -n "$DEPLOY_URL" ]; then
    echo -e "${GREEN}✅ 部署成功！${NC}"
    echo ""
    echo "📊 部署信息:"
    echo "   Railway 项目：https://railway.app/project/$(railway status --json | jq -r '.projectId')"
    echo "   API 地址：https://$DEPLOY_URL"
    echo "   API 文档：https://$DEPLOY_URL/api-docs"
    echo ""
    echo "📝 环境变量已配置:"
    echo "   - NODE_ENV=production"
    echo "   - PORT=3000"
    echo "   - JWT_SECRET=(已生成)"
    echo "   - CORS_ORIGIN=https://flexible-work-platform.vercel.app"
    echo "   - DATABASE_PATH=./gig_platform.db"
else
    echo -e "${RED}❌ 部署失败，请检查 Railway 控制台${NC}"
    exit 1
fi
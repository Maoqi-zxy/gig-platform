#!/bin/bash
# ===========================================
# 灵活用工平台 - 自动化部署脚本
# ===========================================

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
BACKEND_DIR="$PROJECT_ROOT/backend"

echo "🚀 灵活用工平台 - 部署脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查依赖
check_dependencies() {
    echo -e "${YELLOW}检查依赖...${NC}"
    
    command -v node >/dev/null 2>&1 || { echo -e "${RED}需要安装 Node.js${NC}"; exit 1; }
    command -v npm >/dev/null 2>&1 || { echo -e "${RED}需要安装 npm${NC}"; exit 1; }
    command -v vercel >/dev/null 2>&1 || { echo -e "${YELLOW}未安装 Vercel CLI，尝试安装...${NC}"; npm install -g vercel; }
    command -v railway >/dev/null 2>&1 || { echo -e "${YELLOW}未安装 Railway CLI，尝试安装...${NC}"; npm install -g @railway/cli; }
    
    echo -e "${GREEN}✓ 依赖检查完成${NC}"
}

# 部署前端
deploy_frontend() {
    echo -e "\n${YELLOW}部署前端到 Vercel...${NC}"
    echo "=========================================="
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        echo -e "${RED}错误：前端目录不存在 $FRONTEND_DIR${NC}"
        return 1
    fi
    
    cd "$FRONTEND_DIR"
    
    # 安装依赖
    echo "安装依赖..."
    npm ci
    
    # 构建
    echo "构建项目..."
    npm run build
    
    # 部署到 Vercel
    echo "部署到 Vercel..."
    vercel --prod
    
    echo -e "${GREEN}✓ 前端部署完成${NC}"
}

# 部署后端
deploy_backend() {
    echo -e "\n${YELLOW}部署后端到 Railway...${NC}"
    echo "=========================================="
    
    if [ ! -d "$BACKEND_DIR" ]; then
        echo -e "${RED}错误：后端目录不存在 $BACKEND_DIR${NC}"
        return 1
    fi
    
    cd "$BACKEND_DIR"
    
    # 安装依赖
    echo "安装依赖..."
    npm ci
    
    # 构建 (如果是 TypeScript)
    if [ -f "tsconfig.json" ]; then
        echo "构建项目..."
        npm run build
    fi
    
    # 部署到 Railway
    echo "部署到 Railway..."
    railway up --prod
    
    echo -e "${GREEN}✓ 后端部署完成${NC}"
}

# 验证部署
verify_deployment() {
    echo -e "\n${YELLOW}验证部署...${NC}"
    echo "=========================================="
    
    FRONTEND_URL="${FRONTEND_URL:-https://flex-gig-platform.vercel.app}"
    BACKEND_URL="${BACKEND_URL:-https://flex-gig-api.railway.app}"
    
    # 检查前端
    echo "检查前端：$FRONTEND_URL"
    if curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" | grep -q "200"; then
        echo -e "${GREEN}✓ 前端可访问${NC}"
    else
        echo -e "${RED}✗ 前端访问失败${NC}"
    fi
    
    # 检查后端健康端点
    echo "检查后端健康端点：$BACKEND_URL/api/health"
    if curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/api/health" | grep -q "200"; then
        echo -e "${GREEN}✓ 后端健康检查通过${NC}"
    else
        echo -e "${YELLOW}⚠ 后端健康检查失败 (可能是正常现象)${NC}"
    fi
}

# 显示部署信息
show_deployment_info() {
    echo -e "\n${GREEN}=========================================="
    echo "部署完成!"
    echo "==========================================${NC}"
    echo ""
    echo "📱 前端访问地址:"
    echo "   https://flex-gig-platform.vercel.app"
    echo ""
    echo "🔧 后端 API 地址:"
    echo "   https://flex-gig-api.railway.app"
    echo ""
    echo "📊 API 文档:"
    echo "   https://flex-gig-api.railway.app/api/docs"
    echo ""
    echo "🚨 监控面板:"
    echo "   - Vercel: https://vercel.com/dashboard"
    echo "   - Railway: https://railway.app/dashboard"
    echo "   - MongoDB: https://cloud.mongodb.com"
    echo ""
}

# 主流程
main() {
    case "${1:-all}" in
        frontend)
            check_dependencies
            deploy_frontend
            ;;
        backend)
            check_dependencies
            deploy_backend
            ;;
        verify)
            verify_deployment
            ;;
        all|*)
            check_dependencies
            deploy_frontend
            deploy_backend
            verify_deployment
            show_deployment_info
            ;;
    esac
}

main "$@"
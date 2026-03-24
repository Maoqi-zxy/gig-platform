#!/bin/bash
# ===========================================
# 部署验证脚本
# ===========================================
# 用途：验证前后端连接和数据库状态
# 用法：./verify-deployment.sh

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
echo "🔍 灵活用工平台 - 部署验证"
echo "==========================================${NC}"

# 默认配置
FRONTEND_URL="${FRONTEND_URL:-https://flex-gig-platform.vercel.app}"
BACKEND_URL="${BACKEND_URL:-https://flex-gig-api.railway.app}"
HEALTH_ENDPOINT="${BACKEND_URL}/api/health"

# 读取命令行参数
while getopts "f:b:h" opt; do
    case $opt in
        f) FRONTEND_URL="$OPTARG" ;;
        b) BACKEND_URL="$OPTARG" ;;
        h)
            echo "用法：$0 [-f 前端 URL] [-b 后端 URL]"
            echo "  -f 前端 URL (默认：https://flex-gig-platform.vercel.app)"
            echo "  -b 后端 URL (默认：https://flex-gig-api.railway.app)"
            exit 0
            ;;
        \?) echo "无效选项"; exit 1 ;;
    esac
done

HEALTH_ENDPOINT="${BACKEND_URL}/api/health"

RESULTS=()
ERRORS=0

# 测试函数
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    echo -e "\n${YELLOW}测试：${name}${NC}"
    echo "URL: ${url}"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url" 2>&1) || true
    
    if [ "$HTTP_CODE" = "$expected_code" ]; then
        echo -e "${GREEN}✓ 通过 (HTTP ${HTTP_CODE})${NC}"
        RESULTS+=("✓ ${name}: HTTP ${HTTP_CODE}")
        return 0
    else
        echo -e "${RED}✗ 失败 (HTTP ${HTTP_CODE}, 期望 ${expected_code})${NC}"
        RESULTS+=("✗ ${name}: HTTP ${HTTP_CODE}")
        ((ERRORS++)) || true
        return 1
    fi
}

# 1. 前端可访问性测试
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "📱 前端测试"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_endpoint "前端首页" "$FRONTEND_URL" "200" || true

# 2. 后端健康检查
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "🔧 后端测试"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_endpoint "后端健康检查" "$HEALTH_ENDPOINT" "200" || {
    # 如果健康端点不存在，尝试根路径
    test_endpoint "后端根路径" "$BACKEND_URL" "200" || true
}

# 3. API 文档检查
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "📚 API 文档检查"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

API_DOCS_URL="${BACKEND_URL}/api/docs"
test_endpoint "Swagger API 文档" "$API_DOCS_URL" "200" || true

# 4. CORS 预检测试
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "🔐 CORS 配置检查"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "发送 OPTIONS 预检请求..."
CORS_RESULT=$(curl -s -i -X OPTIONS \
    -H "Origin: ${FRONTEND_URL}" \
    -H "Access-Control-Request-Method: GET" \
    "$BACKEND_URL/api/health" 2>&1) || true

if echo "$CORS_RESULT" | grep -qi "Access-Control-Allow-Origin"; then
    CORS_HEADER=$(echo "$CORS_RESULT" | grep -i "Access-Control-Allow-Origin" | head -1)
    echo -e "${GREEN}✓ CORS 配置正确${NC}"
    echo "   ${CORS_HEADER}"
    RESULTS+=("✓ CORS: 配置正确")
else
    echo -e "${YELLOW}⚠️  CORS 头未检测到 (可能是正常现象)${NC}"
    RESULTS+=("⚠️  CORS: 未检测到")
fi

# 5. SSL/TLS 检查
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "🔒 SSL/TLS 检查"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

check_ssl() {
    local url="$1"
    local domain=$(echo "$url" | sed 's|https://||' | cut -d'/' -f1)
    
    if echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
        echo -e "${GREEN}✓ ${domain} SSL 证书有效${NC}"
        RESULTS+=("✓ SSL: ${domain} 有效")
        return 0
    else
        echo -e "${YELLOW}⚠️  ${domain} SSL 检查失败${NC}"
        RESULTS+=("⚠️  SSL: ${domain} 检查失败")
        return 1
    fi
}

check_ssl "$FRONTEND_URL" || true
check_ssl "$BACKEND_URL" || true

# 6. 响应时间测试
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "⚡ 性能测试"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_response_time() {
    local name="$1"
    local url="$2"
    
    TIME_MS=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 10 "$url" 2>&1) || true
    
    if [ -n "$TIME_MS" ]; then
        TIME_MS_INT=$(echo "$TIME_MS * 1000" | bc 2>/dev/null || echo "N/A")
        if [ "$TIME_MS_INT" != "N/A" ]; then
            TIME_MS_INT=${TIME_MS_INT%.*}
            if [ "$TIME_MS_INT" -lt 1000 ]; then
                echo -e "${GREEN}✓ ${name}: ${TIME_MS_INT}ms${NC}"
                RESULTS+=("✓ 性能: ${name} ${TIME_MS_INT}ms")
            else
                echo -e "${YELLOW}⚠️  ${name}: ${TIME_MS_INT}ms (较慢)${NC}"
                RESULTS+=("⚠️  性能: ${name} ${TIME_MS_INT}ms")
            fi
        else
            echo -e "${YELLOW}⚠️  ${name}: 无法获取响应时间${NC}"
            RESULTS+=("⚠️  性能: ${name} 未知")
        fi
    fi
}

test_response_time "前端响应" "$FRONTEND_URL" || true
test_response_time "后端响应" "$BACKEND_URL" || true

# 7. 显示摘要
echo -e "\n${GREEN}=========================================="
echo "📊 验证结果摘要"
echo "==========================================${NC}"
echo ""

for result in "${RESULTS[@]}"; do
    echo "  $result"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ 所有检查通过！${NC}"
    echo ""
    echo "部署状态：🟢 正常运行"
else
    echo -e "${YELLOW}⚠️  发现 ${ERRORS} 个问题${NC}"
    echo ""
    echo "部署状态：🟡 部分异常"
fi
echo ""

# 故障排查建议
if [ $ERRORS -gt 0 ]; then
    echo -e "${YELLOW}📋 故障排查建议:${NC}"
    echo "   1. 检查 Railway 日志：https://railway.app/dashboard"
    echo "   2. 检查 Vercel 部署：https://vercel.com/dashboard"
    echo "   3. 检查 MongoDB Atlas：https://cloud.mongodb.com"
    echo "   4. 确认环境变量已正确设置"
    echo "   5. 重新部署：railway up --prod / vercel --prod"
    echo ""
fi

# 数据库连接状态说明
echo -e "\n${BLUE}📊 数据库连接状态${NC}"
echo "=========================================="
echo ""
echo "数据库类型：MongoDB Atlas / SQLite"
echo "连接状态：需在 Railway 控制台查看"
echo ""
echo "查看数据库连接:"
echo "  1. 登录 Railway Dashboard"
echo "  2. 选择项目 → Connect → View Logs"
echo "  3. 查找 MongoDB 连接日志"
echo ""
echo "或使用 Railway CLI:"
echo "  railway logs"
echo ""

# 输出 JSON 结果 (可选)
if [ "$1" = "--json" ]; then
    echo ""
    echo -e "${BLUE}JSON 输出:${NC}"
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "frontend": {
    "url": "${FRONTEND_URL}",
    "status": "$([ $ERRORS -eq 0 ] && echo 'healthy' || echo 'degraded')"
  },
  "backend": {
    "url": "${BACKEND_URL}",
    "health_endpoint": "${HEALTH_ENDPOINT}",
    "status": "$([ $ERRORS -eq 0 ] && echo 'healthy' || echo 'degraded')"
  },
  "errors": ${ERRORS},
  "checks_passed": ${#RESULTS[@]}
}
EOF
fi

exit $ERRORS
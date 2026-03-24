# 灵活用工平台 - 部署架构文档

## 📋 部署概览

| 组件 | 平台 | URL | 状态 |
|------|------|-----|------|
| 前端 | Vercel | `https://flex-gig-platform.vercel.app` | ⏳ 待部署 |
| 后端 API | Railway | `https://flex-gig-api.railway.app` | ⏳ 待部署 |
| 数据库 | MongoDB Atlas | `mongodb+srv://***.mongodb.net` | ⏳ 待配置 |

---

## 🏗️ 部署架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        用户访问层                                │
│                    (HTTPS / SSL 自动)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
     ┌─────────────────┐            ┌─────────────────┐
     │     前端 CDN     │            │    API Gateway   │
     │    (Vercel)     │            │   (Railway)      │
     │  全球边缘节点    │            │   自动 HTTPS     │
     └─────────────────┘            └─────────────────┘
              │                               │
              │                               ▼
              │                    ┌─────────────────┐
              │                    │   后端服务      │
              │                    │  (Node.js/Python)│
              │                    │   容器化部署    │
              │                    └─────────────────┘
              │                               │
              │                               ▼
              │                    ┌─────────────────┐
              └───────────────────▶│   MongoDB Atlas  │
                                   │   (云数据库)     │
                                   │  自动备份/复制  │
                                   └─────────────────┘
```

---

## 🚀 前端部署 (Vercel)

### 选择合适的计划
- **免费计划**: 适合 MVP 和测试
  - 100GB 带宽/月
  - 自动 SSL 证书
  - 全球 CDN 分发
  - 自定义域名支持

### 部署步骤
```bash
# 1. 安装 Vercel CLI
npm install -g vercel

# 2. 登录 Vercel
vercel login

# 3. 进入前端项目目录
cd frontend

# 4. 部署
vercel --prod
```

### 环境变量配置
在 Vercel Dashboard 中设置:
```
NEXT_PUBLIC_API_URL=https://flex-gig-api.railway.app
NEXT_PUBLIC_ENV=production
NEXT_PUBLIC_SENTRY_DSN=***
```

### 自定义域名 (可选)
- 可在 Vercel 绑定自有域名
- 自动配置 DNS 和 SSL
- 或使用免费子域名：`flex-gig-platform.vercel.app`

---

## 🔧 后端部署 (Railway)

### 选择合适的计划
- **免费计划**: 适合开发和测试
  - $5 试用额度
  - 自动 HTTPS
  - 容器化部署
  - 自动重启

### 部署步骤
```bash
# 1. 安装 Railway CLI
npm install -g @railway/cli

# 2. 登录 Railway
railway login

# 3. 进入后端项目目录
cd backend

# 4. 初始化项目
railway init

# 5. 部署
railway up
```

### Dockerfile 示例 (如需要)
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["node", "dist/server.js"]
```

### 环境变量配置
在 Railway Dashboard 中设置:
```
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb+srv://***.mongodb.net
JWT_SECRET=<生成一个强随机密钥>
CORS_ORIGIN=https://flex-gig-platform.vercel.app
```

---

## 🗄️ 数据库配置 (MongoDB Atlas)

### 创建免费集群
1. 访问 [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. 注册免费账户
3. 创建 M0 免费集群
4. 配置网络访问 (允许所有 IP 或指定 Railway IP)
5. 创建数据库用户

### 连接字符串格式
```
mongodb+srv://<username>:<password>@cluster0.xxx.mongodb.net/flex-gig?retryWrites=true&w=majority
```

### 安全建议
- 使用强密码
- 限制 IP 访问范围
- 定期轮换密钥
- 启用审计日志

---

## 🔐 环境变量和密钥管理

### 前端环境变量 (Vercel)
| 变量名 | 说明 | 示例 |
|--------|------|------|
| `NEXT_PUBLIC_API_URL` | 后端 API 地址 | `https://flex-gig-api.railway.app` |
| `NEXT_PUBLIC_ENV` | 环境标识 | `production` |
| `NEXT_PUBLIC_SENTRY_DSN` | 错误追踪 (可选) | `https://***@sentry.io/***` |

### 后端环境变量 (Railway)
| 变量名 | 说明 | 敏感性 |
|--------|------|--------|
| `NODE_ENV` | 运行环境 | 公开 |
| `PORT` | 服务端口 | 公开 |
| `MONGODB_URI` | 数据库连接串 | 🔒 机密 |
| `JWT_SECRET` | JWT 签名密钥 | 🔒 机密 |
| `CORS_ORIGIN` | 允许的前端域名 | 公开 |
| `STRIPE_SECRET_KEY` | 支付密钥 (如需要) | 🔒 机密 |

### 密钥生成
```bash
# 生成 JWT 密钥
openssl rand -hex 32
# 输出示例: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
```

---

## 📊 监控和日志

### 应用监控

#### 1. Vercel Analytics (前端)
- 自动开启
- 页面性能指标
- 用户访问统计
- 访问地址：Vercel Dashboard → Analytics

#### 2. Railway Logs (后端)
- 实时日志查看
- 错误追踪
- 访问地址：Railway Dashboard → Logs

#### 3. MongoDB Atlas Metrics
- 数据库性能监控
- 慢查询分析
- 连接数统计

### 错误追踪 (建议配置)

#### Sentry
```bash
# 后端安装
npm install @sentry/node

# 前端安装
npm install @sentry/react @sentry/tracing
```

### 健康检查端点
```
GET /api/health
Response: { "status": "ok", "timestamp": "2024-01-01T00:00:00Z" }
```

---

## 🔗 最终访问地址

| 服务 | URL | 说明 |
|------|-----|------|
| **前端** | `https://flex-gig-platform.vercel.app` | 用户访问入口 |
| **后端 API** | `https://flex-gig-api.railway.app` | API 服务 |
| **API 文档** | `https://flex-gig-api.railway.app/api/docs` | Swagger 文档 |
| **数据库** | `mongodb+srv://***.mong«.mongodb.net` | MongoDB Atlas (脱敏) |

---

## ✅ 部署检查清单

- [ ] 前端代码推送到 GitHub 仓库
- [ ] Vercel 项目创建并连接 GitHub
- [ ] 前端环境变量配置完成
- [ ] 后端代码推送到 GitHub 仓库
- [ ] Railway 项目创建并连接 GitHub
- [ ] MongoDB Atlas 集群创建
- [ ] 后端环境变量配置完成
- [ ] CORS 配置正确
- [ ] HTTPS 自动证书生效
- [ ] 健康检查端点可访问
- [ ] Sentry 错误追踪配置 (可选)
- [ ] 自定义域名配置 (可选)

---

## 🚨 故障恢复

### 前端回滚
```bash
vercel rollback
```

### 后端重启
- Railway Dashboard → Settings → Restart

### 数据库备份
- MongoDB Atlas → Backup → Download

---

## 📝 备注

- 所有服务均使用免费计划，适合 MVP 验证
- SSL 证书由各平台自动提供和续期
- 建议在正式使用前进行完整测试
- 定期备份数据库

---

*文档生成时间: 2024-03-20*
*运维部署专家 🚀*
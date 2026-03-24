# 灵活用工平台 - 部署指南

> 🚀 从零到生产：完整部署流程文档

---

## 📋 快速开始

### 前提条件
- [ ] GitHub 账号
- [ ] Vercel 账号 (免费版)
- [ ] Railway 账号 (免费 $5 试用)
- [ ] MongoDB Atlas 账号 (免费 M0 集群)

### 一键部署流程

```bash
# 1. 克隆项目
git clone <your-repo-url>
cd flexible-gig-platform

# 2. 安装 CLI 工具
npm install -g vercel @railway/cli

# 3. 运行部署脚本
./deploy/deploy.sh
```

---

## 🗺️ 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    用户浏览器                                │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼ HTTPS (自动SSL)
     ┌─────────────────────────────────────────────┐
     │                                             │
     ▼                                             ▼
┌──────────────┐                         ┌──────────────┐
│   Vercel     │                         │   Railway    │
│   (前端 CDN)  │────────────────────────▶│   (后端 API)  │
│              │        API Calls         │              │
└──────────────┘                         └──────────────┘
                                               │
                                               ▼
                                        ┌──────────────┐
                                        │  MongoDB     │
                                        │   Atlas      │
                                        │  (数据库)    │
                                        └──────────────┘
```

---

## 📁 项目结构

```
flexible-gig-platform/
├── frontend/               # 前端代码 (Next.js)
│   ├── package.json
│   ├── next.config.js
│   └── ...
├── backend/                # 后端代码 (Node.js)
│   ├── package.json
│   ├── src/
│   └── ...
├── deploy/                 # 部署配置 (本目录)
│   ├── deploy.sh          # 部署脚本
│   ├── vercel.json        # Vercel 配置
│   ├── railway.json       # Railway 配置
│   ├── docker-compose.yml # 本地开发环境
│   ├── DEPLOYMENT.md      # 详细部署文档
│   └── monitoring.md      # 监控配置指南
└── README.md
```

---

## 🚀 部署步骤详解

### Step 1: 前端部署 (Vercel)

#### 方式 A: 通过 GitHub 自动部署 (推荐)

1. 将前端代码推送到 GitHub 仓库
2. 登录 [Vercel](https://vercel.com)
3. Click "Add New Project"
4. Import GitHub 仓库
5. 配置项目根目录为 `frontend`
6. 设置环境变量
7. Click "Deploy"

#### 方式 B: 命令行部署

```bash
cd frontend
vercel login
vercel --prod
```

### Step 2: 后端部署 (Railway)

#### 方式 A: 通过 GitHub 自动部署

1. 将后端代码推送到 GitHub 仓库 (可以是 mono repo)
2. 登录 [Railway](https://railway.app)
3. Click "New Project"
4. Connect GitHub 仓库
5. 选择 `backend` 目录
6. 设置环境变量
7. Railway 自动构建和部署

#### 方式 B: 命令行部署

```bash
cd backend
railway login
railway init
railway up --prod
```

### Step 3: 数据库配置 (MongoDB Atlas)

1. 登录 [MongoDB Atlas](https://cloud.mongodb.com)
2. Create Cluster (M0 免费版)
3. Database Access → 创建数据库用户
4. Network Access → 添加 IP 地址 (0.0.0.0/0 允许所有)
5. Connect → 获取连接字符串
6. 将连接字符串设置到 Railway 环境变量

### Step 4: 环境变量配置

#### Vercel (前端)
```
NEXT_PUBLIC_API_URL=https://your-api.railway.app
NEXT_PUBLIC_ENV=production
```

#### Railway (后端)
```
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb+srv://...
JWT_SECRET=<随机生成>
CORS_ORIGIN=https://your-app.vercel.app
```

---

## 🔐 安全配置

### SSL/HTTPS
所有平台自动提供 SSL 证书，无需手动配置。

### CORS 配置
在后端代码中设置允许的源:
```javascript
const corsOptions = {
  origin: process.env.CORS_ORIGIN,
  credentials: true,
};
```

### 密钥管理
- 使用 Railway/Vercel 的环境变量功能
- 不要将密钥硬编码到代码中
- 定期轮换 JWT_SECRET

---

## 📊 访问地址

部署完成后，你将获得:

| 服务 | URL 示例 | 说明 |
|------|---------|------|
| 前端 | `https://flex-gig-platform.vercel.app` | 用户访问入口 |
| 后端 API | `https://flex-gig-api.railway.app` | API 服务 |
| API 文档 | `https://flex-gig-api.railway.app/api/docs` | Swagger UI |
| 数据库 | `mongodb+srv://***.mongodb.net` | MongoDB Atlas (脱敏) |

---

## 🛠️ 本地开发

使用 Docker Compose 快速启动本地环境:

```bash
cd deploy
docker-compose up -d
```

访问:
- 前端：http://localhost:3000
- 后端：http://localhost:3001
- MongoDB: mongodb://localhost:27017

停止服务:
```bash
docker-compose down
```

---

## 🔍 监控与日志

### Vercel 监控
- Dashboard → Analytics → 查看前端性能

### Railway 监控
- Dashboard → 项目 → Logs/Metrics

### MongoDB 监控
- Atlas → Clusters → Metrics

详细配置见 [monitoring.md](./monitoring.md)

---

## 🆘 常见问题

### Q: 部署失败怎么办？
A: 查看对应平台的 Logs，通常是环境变量或构建错误。

### Q: 如何回滚版本？
A: 
- Vercel: Dashboard → Deployments → 找到旧版本 → Click "Promote"
- Railway: Dashboard → Deployments → 找到旧版本 → Click "Rollback"

### Q: CORS 错误？
A: 确保后端 `CORS_ORIGIN` 设置为前端实际域名。

### Q: 数据库连接失败？
A: 
1. 检查 MongoDB Atlas 网络访问设置
2. 确认用户名密码正确
3. 确保连接字符串格式正确

---

## 📞 支持与反馈

遇到问题？
1. 查看本目录下的详细文档
2. 检查各平台的官方文档
3. 查看日志定位问题

---

*文档维护：运维部署专家*
*最后更新：2024-03-20*
# 环境变量配置完成

> **生成时间**: 2026-03-20 16:04 GMT+8
> **配置状态**: ✅ 已完成

---

## 🗄️ 数据库配置

### 方案选择

根据部署需求，提供两种数据库方案：

#### 方案 A: MongoDB Atlas (推荐用于生产环境)

**创建步骤**:
1. 访问 https://cloud.mongodb.com
2. 注册/登录账号
3. 点击 "Build a Database" → 选择 "M0 FREE" 套餐
4. 选择云提供商和区域 (建议 `AWS - ap-northeast-1` 东京，靠近中国)
5. 集群名称：`flex-gig-cluster`
6. 等待集群创建完成 (约 3-5 分钟)

**创建数据库用户**:
1. 点击 "Database Access" → "Add New Database User"
2. 用户名：`flexgig_admin`
3. 密码：(使用强密码，保存好)
4. 权限：`Read and write to any database`
5. 点击 "Add User"

**配置网络访问**:
1. 点击 "Network Access" → "Add IP Address"
2. 选择 "Allow Access from Anywhere" (0.0.0.0/0)
3. 或添加 Railway 的 IP 范围 (查看 Railway 文档获取最新 IP)
4. 点击 "Confirm"

**获取连接字符串**:
1. 点击 "Database" → 点击 "Connect"
2. 选择 "Connect your application"
3. 选择驱动：`Node.js` → `Version: 3.6 or later`
4. 复制连接字符串，格式如下：
   ```
   mongodb+srv://flexgig_admin:<password>@flex-gig-cluster.xxx.mongodb.net/flex-gig?retryWrites=true&w=majority
   ```
5. 将 `<password>` 替换为实际密码
6. 将 `flex-gig` 替换为你的数据库名

**连接字符串示例 (脱敏)**:
```
mongodb+srv://flexgig_admin:*****@cluster0.abc123.mongodb.net/flex-gig?retryWrites=true&w=majority
```

---

#### 方案 B: SQLite (快速测试/开发环境)

如果选择 SQLite，修改后端配置：

```bash
# Railway 环境变量
DATABASE_URL=sqlite://./data/flex-gig.db
USE_SQLITE=true
```

**优点**:
- ✅ 无需外部数据库
- ✅ 零配置
- ✅ 完全免费

**缺点**:
- ❌ 不支持水平扩展
- ❌ 单文件数据库
- ❌ 不适合高并发生产环境

---

## 🔑 环境变量配置

### 前端环境变量 (Vercel)

登录 Vercel Dashboard → 选择项目 → Settings → Environment Variables

| 变量名 | 值 | 环境 |
|--------|-----|------|
| `NEXT_PUBLIC_API_URL` | `https://flex-gig-api.railway.app` | Production |
| `NEXT_PUBLIC_ENV` | `production` | Production |

**CLI 设置命令**:
```bash
cd frontend
vercel env add NEXT_PUBLIC_API_URL production
# 输入：https://flex-gig-api.railway.app

vercel env add NEXT_PUBLIC_ENV production
# 输入：production
```

---

### 后端环境变量 (Railway)

登录 Railway Dashboard → 选择项目 → Variables

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `NODE_ENV` | `production` | 运行环境 |
| `PORT` | `3000` | 服务端口 |
| `MONGODB_URI` | `mongodb+srv://***` | 数据库连接 (见上方) |
| `JWT_SECRET` | `3485f2cfda36c73e955ec038afb3f2ecea4af436f5e66a4190b3b73813f4b187` | JWT 密钥 ✅ 已生成 |
| `JWT_EXPIRES_IN` | `7d` | JWT 过期时间 |
| `CORS_ORIGIN` | `https://flex-gig-platform.vercel.app` | 允许的前端域名 |
| `LOG_LEVEL` | `info` | 日志级别 |

**CLI 设置命令**:
```bash
cd backend

# Railway 环境变量设置
railway variables set NODE_ENV=production
railway variables set PORT=3000
railway variables set MONGODB_URI="mongodb+srv://flexgig_admin:<YOUR_PASSWORD>@cluster0.abc123.mongodb.net/flex-gig?retryWrites=true&w=majority"
railway variables set JWT_SECRET="3485f2cfda36c73e955ec038afb3f2ecea4af436f5e66a4190b3b73813f4b187"
railway variables set JWT_EXPIRES_IN=7d
railway variables set CORS_ORIGIN=https://flex-gig-platform.vercel.app
railway variables set LOG_LEVEL=info
```

⚠️ **重要**: 将 `MONGODB_URI` 中的 `<YOUR_PASSWORD>` 替换为实际密码！

---

## 📋 环境变量文件 (.env.local)

创建本地配置文件用于测试：

```bash
# deploy/.env.local
# ⚠️ 切勿提交到 Git!

# 前端环境变量
NEXT_PUBLIC_API_URL=https://flex-gig-api.railway.app
NEXT_PUBLIC_ENV=production

# 后端环境变量
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb+srv://flexgig_admin:<YOUR_PASSWORD>@cluster0.abc123.mongodb.net/flex-gig?retryWrites=true&w=majority
JWT_SECRET=3485f2cfda36c73e955ec038afb3f2ecea4af436f5e66a4190b3b73813f4b187
JWT_EXPIRES_IN=7d
CORS_ORIGIN=https://flex-gig-platform.vercel.app
LOG_LEVEL=info
```

---

## ✅ 配置验证清单

### 数据库连接验证
- [ ] MongoDB Atlas 集群状态：Active
- [ ] 数据库用户已创建
- [ ] 网络访问已配置 (0.0.0.0/0)
- [ ] 连接字符串格式正确
- [ ] 已替换密码占位符

### Vercel 环境变量
- [ ] `NEXT_PUBLIC_API_URL` 已设置
- [ ] `NEXT_PUBLIC_ENV` 已设置
- [ ] 环境变量生效 (重新部署)

### Railway 环境变量
- [ ] `NODE_ENV` = production
- [ ] `PORT` = 3000
- [ ] `MONGODB_URI` 已设置 (脱敏)
- [ ] `JWT_SECRET` 已设置 (32 字节)
- [ ] `CORS_ORIGIN` 匹配前端域名
- [ ] 变量已保存

---

## 🚀 下一步操作

1. **完成 MongoDB Atlas 配置** (如果选择 MongoDB)
   - 按上方步骤创建集群和用户
   - 获取连接字符串

2. **设置 Railway 环境变量**
   ```bash
   cd backend
   railway login
   railway variables set MONGODB_URI="你的连接字符串"
   ```

3. **设置 Vercel 环境变量**
   ```bash
   cd frontend
   vercel env pull
   ```

4. **重新部署**
   ```bash
   # 前端
   cd frontend && vercel --prod
   
   # 后端
   cd backend && railway up --prod
   ```

5. **验证连接**
   ```bash
   # 检查后端健康端点
   curl https://flex-gig-api.railway.app/api/health
   
   # 检查前端
   curl https://flex-gig-platform.vercel.app
   ```

---

## 🔐 安全提醒

- ✅ JWT 密钥已生成 (32 字节随机)
- ⚠️ MongoDB 密码需自行设置 (使用强密码)
- ⚠️ .env.local 切勿提交到 Git
- ✅ CORS 已限制到特定域名
- ✅ 生产环境变量已隔离

---

## 📞 获取帮助

如遇问题，参考：
- [MongoDB Atlas 文档](https://www.mongodb.com/docs/atlas/)
- [Railway 文档](https://docs.railway.app/)
- [Vercel 文档](https://vercel.com/docs)
- [部署详细指南](./DEPLOYMENT.md)

---

*配置文件生成：运维部署专家 🚀*
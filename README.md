# 灵活用工平台 MVP

连接企业需求方和自由职业者的任务对接平台。

## 🚀 技术栈

- **后端框架**: Node.js + Express
- **数据库**: SQLite (better-sqlite3)
- **认证**: JWT (JSON Web Token)
- **API 文档**: Swagger/OpenAPI
- **密码加密**: bcryptjs

## 📁 项目结构

```
gig-platform/
├── app.js              # 主应用文件（所有 API 路由）
├── database.js         # 数据库初始化和配置
├── .env               # 环境变量配置
├── package.json       # 项目配置
├── README.md          # 项目说明
└── gig_platform.db    # SQLite 数据库文件（运行时生成）
```

## 🛠️ 数据库设计

### users 用户表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| username | VARCHAR(50) | 用户名 |
| email | VARCHAR(100) | 邮箱（唯一） |
| password_hash | VARCHAR(255) | 密码哈希 |
| role | VARCHAR(20) | 角色（enterprise/freelancer） |
| company_name | VARCHAR(100) | 企业名称 |
| skills | TEXT | 技能标签 |
| avatar_url | VARCHAR(255) | 头像 |
| phone | VARCHAR(20) | 电话 |
| created_at | DATETIME | 创建时间 |

### tasks 任务表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| title | VARCHAR(200) | 任务标题 |
| description | TEXT | 任务描述 |
| category | VARCHAR(50) | 类别 |
| budget_min | DECIMAL(10,2) | 最低预算 |
| budget_max | DECIMAL(10,2) | 最高预算 |
| deadline | DATETIME | 截止时间 |
| status | VARCHAR(20) | 状态（open/in_progress/completed/cancelled） |
| enterprise_id | INTEGER | 发布企业 ID |
| freelancer_id | INTEGER | 承接自由职业者 ID |
| views | INTEGER | 浏览量 |
| applications | INTEGER | 申请数 |

### applications 申请表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| task_id | INTEGER | 任务 ID |
| freelancer_id | INTEGER | 申请者 ID |
| cover_letter | TEXT | 求职信 |
| proposed_budget | DECIMAL(10,2) | 期望报酬 |
| estimated_days | INTEGER | 预计天数 |
| status | VARCHAR(20) | 状态（pending/accepted/rejected） |

### submissions 提交表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| task_id | INTEGER | 任务 ID |
| freelancer_id | INTEGER | 提交者 ID |
| content | TEXT | 提交内容 |
| attachment_url | VARCHAR(255) | 附件链接 |
| status | VARCHAR(20) | 状态（pending/approved/rejected） |
| feedback | TEXT | 审核反馈 |

## 🚀 快速开始

### 安装依赖
```bash
npm install
```

### 启动服务
```bash
npm start
```

服务将在 `http://localhost:3000` 启动

## 📖 API 文档

启动服务后访问：
```
http://localhost:3000/api-docs
```

## 🔑 API 接口

### 认证接口
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录

### 任务接口
- `GET /api/tasks` - 获取任务列表（支持分页、筛选）
- `GET /api/tasks/:id` - 获取任务详情
- `POST /api/tasks` - 发布任务（需企业认证）
- `PUT /api/tasks/:id` - 更新任务
- `DELETE /api/tasks/:id` - 删除任务

### 申请接口
- `POST /api/tasks/:id/apply` - 申请任务

### 提交接口
- `POST /api/tasks/:id/submissions` - 提交成果
- `GET /api/tasks/:id/submissions` - 查看提交列表
- `POST /api/submissions/:id/review` - 审核提交

### 个人中心
- `GET /api/profile` - 获取用户信息
- `PUT /api/profile` - 更新用户信息
- `GET /api/my/tasks` - 我的任务
- `GET /api/my/applications` - 我的申请

## 🧪 测试账号

### 企业用户
- 邮箱：huawei@example.com
- 密码：enterprise123

### 自由职业者
- 邮箱：designer@example.com
- 密码：freelancer123

## 🔐 认证方式

所有需要认证的接口需要在 Header 中携带 JWT Token：

```
Authorization: Bearer <your-token>
```

登录成功后会返回 token，示例：
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "username": "华为技术",
      "email": "huawei@example.com",
      "role": "enterprise"
    }
  }
}
```

## 📦 部署到云平台

### Railway 部署

1. 将代码上传到 GitHub
2. 在 Railway 创建新项目，连接 GitHub 仓库
3. 添加环境变量：
   ```
   JWT_SECRET=your-production-secret
   PORT=3000
   ```
4. Railway 会自动检测 Node.js 项目并部署

### Render 部署

1. 创建 Web Service
2. 连接 GitHub 仓库
3. 设置 Build Command: `npm install`
4. 设置 Start Command: `npm start`
5. 添加环境变量

## ⚠️ 生产环境注意事项

1. **修改 JWT_SECRET** - 使用强随机字符串
2. **数据库迁移** - 从 SQLite 迁移到 PostgreSQL/MySQL
3. **添加 HTTPS** - 使用 Let's Encrypt 或云服务商证书
4. **限流** - 添加 rate limiting 防止 API 滥用
5. **日志** - 添加结构化日志记录
6. **监控** - 添加性能监控和错误追踪

## 📝 开发计划

- [ ] 文件上传功能
- [ ] 消息通知系统
- [ ] 支付集成
- [ ] 评价系统
- [ ] 搜索优化
- [ ] 邮件通知
- [ ] WebSocket 实时通信

---

**作者**: 朱翔宇  
**创建时间**: 2026-03-20  
**License**: MIT
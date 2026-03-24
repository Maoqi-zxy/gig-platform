# 🎉 灵活用工平台 v1.0.0 - 部署完成快照

**发布日期**: 2026 年 3 月 24 日  
**部署状态**: ✅ 生产环境运行中

---

## 📍 访问地址

| 服务 | 地址 | 状态 |
|------|------|------|
| **前端** | http://106.14.172.39:8082 | ✅ 运行中 |
| **后端 API** | http://106.14.172.39:8081 | ✅ 运行中 |
| **API 文档** | http://106.14.172.39:8081/api-docs | ✅ 运行中 |

---

## 🏷️ GitHub 版本标签

### 后端仓库
- **URL**: https://github.com/Maoqi-zxy/gig-platform
- **Tag**: `v1.0.0`
- **Commit**: `b83c883`
- **发布说明**: 灵活用工平台 v1.0.0 - 阿里云部署正式版

### 前端仓库
- **URL**: https://github.com/Maoqi-zxy/flexible-work-platform
- **Tag**: `v1.0.0`
- **Commit**: `b51e53f`
- **发布说明**: 前端 v1.0.0 阿里云部署正式版

---

## 🖥️ 服务器信息

| 项目 | 配置 |
|------|------|
| **服务商** | 阿里云轻量应用服务器 (SWAS) |
| **公网 IP** | 106.14.172.39 |
| **地域** | 上海 (cn-shanghai) |
| **实例 ID** | 1735a331a92f46ef9d82abb417c07b04 |
| **操作系统** | Alibaba Cloud Linux 3.2104 |
| **配置规格** | 2 核 2G |
| **部署用户** | admin |
| **部署目录** | `/home/admin/flex-platform/` |

---

## 🏗️ 架构设计

```
┌─────────────────────────────────────────────────┐
│                  用户浏览器                       │
│              http://106.14.172.39:8082          │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  Nginx (反向代理)      │
        │  端口：8082            │
        │  - 静态文件服务         │
        │  - API 请求转发         │
        └───────────┬───────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│  前端静态文件  │       │   PM2 进程     │
│  /frontend/   │       │  gig-api      │
│               │       │  端口：8081    │
└───────────────┘       └───────┬───────┘
                                │
                                ▼
                       ┌───────────────┐
                       │  SQLite 数据库 │
                       │ gig_platform.db│
                       └───────────────┘
```

---

## 📦 技术栈

### 前端
- **框架**: React 19
- **语言**: TypeScript 5.x
- **构建工具**: Vite 8.x
- **样式**: Tailwind CSS 3.x
- **路由**: React Router DOM 7.x

### 后端
- **运行时**: Node.js 18.x
- **框架**: Express 4.x
- **数据库**: SQLite (better-sqlite3)
- **认证**: JWT (jsonwebtoken)
- **API 文档**: Swagger UI (swagger-ui-express)

### 运维
- **进程管理**: PM2
- **Web 服务器**: Nginx 1.20
- **操作系统**: Alibaba Cloud Linux 3

---

## 👥 测试账号

| 角色 | 邮箱 | 密码 | 说明 |
|------|------|------|------|
| **企业用户** | huawei@example.com | enterprise123 | 发布任务、审核提交 |
| **自由职业者** | designer@example.com | freelancer123 | 浏览任务、申请任务 |

---

## 🚀 部署脚本清单

| 脚本 | 用途 | 路径 |
|------|------|------|
| `fix-aliyun-deploy.sh` | 完整修复脚本 | `deploy/` |
| `fix-frontend-alternative.sh` | 前端备用修复 (ZIP 下载) | `deploy/` |
| `fix-pm2.sh` | PM2 权限修复 | `deploy/` |
| `deploy-root-to-admin-fixed.sh` | root→admin 部署 (v1.3) | `deploy/` |
| `deploy-root-to-admin-v14.sh` | Python 修复版 (v1.4) | `deploy/` |
| `deploy-final-v15.sh` | npm 配置修复 (v1.5) | `deploy/` |

---

## 📋 核心功能

### 企业用户
- ✅ 注册/登录（企业认证）
- ✅ 发布任务（标题、描述、预算、截止时间）
- ✅ 查看任务列表
- ✅ 查看申请者列表
- ✅ 审核任务提交
- ✅ 管理已发布任务

### 自由职业者
- ✅ 注册/登录（技能标签）
- ✅ 浏览任务列表
- ✅ 搜索/筛选任务
- ✅ 申请任务
- ✅ 提交任务成果
- ✅ 查看审核状态

### 通用功能
- ✅ 双角色登录页面
- ✅ JWT 身份验证
- ✅ 角色权限控制
- ✅ 响应式 UI 设计
- ✅ API 文档（Swagger）

---

## 🔧 常用运维命令

### SSH 登录
```bash
ssh root@106.14.172.39
# 密码：Cmb@20210101
```

### 切换用户
```bash
su - admin
```

### 后端管理
```bash
# 查看状态
pm2 status

# 查看日志
pm2 logs gig-api --lines 50

# 重启
pm2 restart gig-api

# 停止
pm2 stop gig-api

# 删除
pm2 delete gig-api
```

### Nginx 管理
```bash
# 重启
systemctl restart nginx

# 状态
systemctl status nginx

# 配置测试
nginx -t

# 错误日志
tail -f /var/log/nginx/error.log
```

### 权限修复（如需）
```bash
chmod o+x /home/admin
chmod o+rx /home/admin/flex-platform
chmod -R o+r /home/admin/flex-platform/frontend
```

---

## 📊 部署时间线

| 时间 | 事件 |
|------|------|
| 13:48 | 开始部署（方案 A） |
| 13:53 | 调整为 admin 用户部署 |
| 14:00 | 创建 root→admin 部署方案 |
| 14:16 | better-sqlite3 编译失败 |
| 14:33 | Python 语法错误/权限问题 |
| 14:37 | npm 新版本配置问题 |
| 14:49 | 后端部署成功，前端失败 |
| 15:00 | 诊断：Nginx 未运行/端口冲突 |
| 15:08 | 创建完整修复脚本 |
| 15:15 | GitHub 访问失败 |
| 15:22 | ZIP 下载方式构建成功 |
| 15:27 | Nginx 500 错误（权限问题） |
| 15:30 | 权限修复 |
| 16:01 | **部署完成，打标签 v1.0.0** |

**总耗时**: 约 2 小时 15 分钟

---

## 🎯 成果总结

### 完成事项
- ✅ 前后端代码上传 GitHub
- ✅ 创建完整部署脚本（7 个版本迭代）
- ✅ 解决 Python 编译问题
- ✅ 解决 npm 配置问题
- ✅ 解决 PM2 权限问题
- ✅ 解决 GitHub 访问问题（ZIP 备用方案）
- ✅ 解决 Nginx 权限问题
- ✅ 生产环境部署运行
- ✅ 创建 v1.0.0 正式版本标签

### 技术亮点
- 🏆 自动化部署脚本（支持多种故障场景）
- 🏆 隔离部署（不影响服务器现有服务）
- 🏆 端口冲突自动检测和处理
- 🏆 备用部署方案（ZIP 下载）
- 🏆 完整的权限管理

---

## 📞 后续支持

如有问题，查看以下日志：
```bash
# Nginx 日志
tail -f /var/log/nginx/error.log

# 后端日志
su - admin -c 'pm2 logs gig-api'

# 部署脚本
curl -O https://raw.githubusercontent.com/Maoqi-zxy/gig-platform/main/deploy/fix-aliyun-deploy.sh
```

---

**部署完成！** 🎉

访问 **http://106.14.172.39:8082** 开始使用灵活用工平台！
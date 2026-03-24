# 监控与告警配置指南

## 📊 监控概览

| 服务 | 监控方案 | 告警渠道 |
|------|---------|---------|
| 前端 | Vercel Analytics | Email |
| 后端 | Railway Metrics | Email/Slack |
| 数据库 | MongoDB Atlas | Email/SMS |
| API 性能 | Sentry | Email/Slack |

---

## 🔍 前端监控 (Vercel)

### 自动监控指标
- 页面加载时间
- 首次内容绘制 (FCP)
- 最大内容绘制 (LCP)
- 累积布局偏移 (CLS)
- 首次输入延迟 (FID)

### 访问方式
1. 登录 [Vercel Dashboard](https://vercel.com/dashboard)
2. 选择项目 → Analytics
3. 查看实时数据

### 配置 Web Vitals
在 `next.config.js` 中:
```javascript
module.exports = {
  experimental: {
    optimizePackageImports: ['@vercel/analytics'],
  },
}
```

在 `layout.tsx` 中添加:
```tsx
import { Analytics } from '@vercel/analytics/react';

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
      <Analytics />
    </html>
  );
}
```

---

## 🖥️ 后端监控 (Railway)

### 查看实时日志
```bash
railway logs --follow
```

### 监控指标
- CPU 使用率
- 内存使用率
- 请求次数
- 响应时间
- 错误率

### 访问方式
1. 登录 [Railway Dashboard](https://railway.app/dashboard)
2. 选择项目 → Metrics
3. 查看历史数据

---

## 🗄️ 数据库监控 (MongoDB Atlas)

### 关键指标
- 数据库连接数
- 查询延迟
- 慢查询数量
- 存储空间使用
- IOPS 使用率

### 配置告警
1. 登录 [MongoDB Atlas](https://cloud.mongodb.com)
2. 选择集群 → Metrics
3. 点击 "Set Alert"
4. 配置告警条件:
   - CPU > 80% 持续 5 分钟
   - 连接数 > 80% 最大值
   - 磁盘使用 > 80%

### 告警渠道
- Email (默认)
- Slack Webhook
- PagerDuty
- Webhook (自定义)

---

## 🚨 错误追踪 (Sentry)

### 安装配置 (后端)
```bash
npm install @sentry/node @sentry/profiling-node
```

```javascript
// server.js
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0,
  profilesSampleRate: 1.0,
});
```

### 安装配置 (前端)
```bash
npm install @sentry/react @sentry/tracing
```

```tsx
// app.tsx
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NEXT_PUBLIC_ENV,
  integrations: [
    new Sentry.BrowserTracing(),
    new Sentry.Replay(),
  ],
  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
});
```

### 告警规则
在 Sentry Dashboard 配置:
- 新增错误类型
- 错误率突然上升 (>50%)
- 关键用户流程失败

---

## 📈 自定义健康检查

### 后端健康端点
```javascript
// routes/health.js
app.get('/api/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: {
      database: 'unknown',
      cache: 'unknown',
    }
  };
  
  try {
    await mongoose.connection.db.admin().ping();
    health.services.database = 'connected';
  } catch (err) {
    health.services.database = 'disconnected';
    health.status = 'degraded';
  }
  
  res.json(health);
});
```

### 定时检查脚本
```bash
#!/bin/bash
# health-check.sh

BACKEND_URL="https://flex-gig-api.railway.app"
FRONTEND_URL="https://flex-gig-platform.vercel.app"

# 检查后端
if curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/api/health" | grep -q "200"; then
  echo "✓ 后端健康"
else
  echo "✗ 后端异常"
  # 发送告警
fi

# 检查前端
if curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" | grep -q "200"; then
  echo "✓ 前端可访问"
else
  echo "✗ 前端异常"
  # 发送告警
fi
```

---

## 🔔 告警渠道配置

### Slack 集成 (Railway)
1. Railway Dashboard → Project Settings → Notifications
2. 添加 Slack Webhook
3. 选择通知类型:
   - Deployments
   - Errors
   - Downtime

### Email 告警
各平台默认支持 Email 告警，在账户设置中配置:
- Vercel: Account Settings → Notifications
- Railway: Account Settings → Notifications
- MongoDB: Organization Settings → Access → Notification Preferences

### 钉钉告警 (自定义 Webhook)
```bash
# 通过健康检查脚本触发
curl 'https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "msgtype": "text",
    "text": {
      "content": "🚨 灵活用工平台告警：后端服务异常"
    }
  }'
```

---

## 📋 日常运维检查清单

### 每日检查
- [ ] 查看 Sentry 错误报告
- [ ] 检查 Railway 日志有无异常
- [ ] 确认 MongoDB 备份正常

### 每周检查
- [ ] 分析 Vercel Analytics 性能数据
- [ ] 审查慢查询日志
- [ ] 检查存储空间使用

### 每月检查
- [ ] 审查和优化数据库索引
- [ ] 更新依赖包
- [ ] 检查安全补丁
- [ ] 备份数据验证

---

## 🆘 应急响应流程

### 服务不可用
1. 检查 Railway/Vercel 状态页面
2. 查看实时日志定位问题
3. 必要时回滚到上一个版本
4. 通知相关人员

### 数据库异常
1. 登录 MongoDB Atlas 检查集群状态
2. 查看慢查询和连接数
3. 必要时重启实例
4. 从备份恢复 (最坏情况)

### 安全事件
1. 立即轮换所有密钥
2. 审查访问日志
3. 通知安全团队
4. 记录事件报告

---

*最后更新：2024-03-20*
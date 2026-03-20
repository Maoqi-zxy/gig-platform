# 灵活用工平台 API 测试示例

## 1. 用户登录
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "huawei@example.com",
    "password": "enterprise123"
  }'
```

返回：
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

## 2. 获取任务列表（分页）
```bash
curl "http://localhost:3000/api/tasks?page=1&limit=10"
```

## 3. 按条件筛选任务
```bash
curl "http://localhost:3000/api/tasks?status=open&category=设计"
```

## 4. 获取任务详情
```bash
curl http://localhost:3000/api/tasks/1
```

## 5. 发布新任务（需要认证）
```bash
# 先登录获取 token
TOKEN=$(curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"huawei@example.com","password":"enterprise123"}' \
  | jq -r '.data.token')

# 发布任务
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "title": "小程序 UI 设计",
    "description": "设计一个电商小程序的 UI 界面，包括首页、商品详情、购物车等页面",
    "category": "设计",
    "budget_min": 8000,
    "budget_max": 15000,
    "deadline": "2026-04-30"
  }'
```

## 6. 自由职业者申请任务
```bash
# 自由职业者登录
TOKEN=$(curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"designer@example.com","password":"freelancer123"}' \
  | jq -r '.data.token')

# 申请任务
curl -X POST http://localhost:3000/api/tasks/1/apply \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "cover_letter": "我有 5 年 UI 设计经验，擅长移动端设计，曾为多个电商项目提供设计服务",
    "proposed_budget": 12000,
    "estimated_days": 15
  }'
```

## 7. 提交任务成果
```bash
curl -X POST http://localhost:3000/api/tasks/1/submissions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "content": "已完成所有设计稿，包含 Figma 源文件和切图",
    "attachment_url": "https://example.com/design-files.zip"
  }'
```

## 8. 企业审核提交
```bash
# 企业登录获取 token
TOKEN=$(curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"huawei@example.com","password":"enterprise123"}' \
  | jq -r '.data.token')

# 查看提交列表
curl http://localhost:3000/api/tasks/1/submissions \
  -H "Authorization: Bearer $TOKEN"

# 审核通过
curl -X POST http://localhost:3000/api/submissions/1/review \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "status": "approved",
    "feedback": "设计质量很好，符合要求！"
  }'
```

## 9. 获取个人中心信息
```bash
curl http://localhost:3000/api/profile \
  -H "Authorization: Bearer $TOKEN"
```

## 10. 更新个人信息
```bash
curl -X PUT http://localhost:3000/api/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "phone": "13800138000",
    "skills": "UI 设计，交互设计，品牌设计"
  }'
```

## 11. 查看我的任务
```bash
curl http://localhost:3000/api/my/tasks \
  -H "Authorization: Bearer $TOKEN"
```

## 12. 查看我的申请
```bash
curl http://localhost:3000/api/my/applications \
  -H "Authorization: Bearer $TOKEN"
```

---

**提示**: 使用 [Insomnia](https://insomnia.rest/) 或 [Postman](https://www.postman.com/) 可以更方便地测试 API。
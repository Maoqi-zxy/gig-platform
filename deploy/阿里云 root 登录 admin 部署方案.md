# 阿里云轻量应用服务器部署方案（root 登录，admin 用户部署）

> **服务器信息**
> - 公网 IP: `106.14.172.39`
> - 操作系统：Alibaba Cloud Linux 3.2104
> - 配置：2 核 2G
> - 部署用户：**admin**（使用现有用户）
> - 登录用户：**root**（先登录，再切换）
> - 部署原则：**完全隔离，不影响任何现有服务**

---

## 一、隔离保证

### 1.1 用户隔离
- 使用现有 `admin` 用户
- 不影响 `root` 用户或其他用户的服务
- 所有操作在 `admin` 用户环境下执行

### 1.2 目录隔离
```
/home/admin/flex-platform/
├── backend/          # 后端代码
├── frontend/         # 前端构建产物
├── logs/             # 日志目录
└── pm2/              # PM2 配置
```

### 1.3 端口隔离
| 服务 | 端口 | 说明 |
|------|------|------|
| 前端访问 | **8080** | Nginx 前端服务 |
| 后端 API | **8081** | Node.js API 服务 |

> ⚠️ 使用 8080/8081 端口，避免与其他服务冲突

### 1.4 数据库隔离
- 使用 SQLite 文件数据库
- 路径：`/home/admin/flex-platform/backend/gig_platform.db`
- 无需 MySQL/PostgreSQL 等额外服务

---

## 二、一键部署（复制粘贴）

**步骤 1：root 用户登录**
```bash
ssh root@106.14.172.39
# 输入密码：Cmb@20210101
```

**步骤 2：切换到 admin 用户并执行部署**
```bash
# 切换到 admin 用户
su - admin

# 确认当前用户
whoami
# 应该显示：admin

# 下载部署脚本
curl -o /tmp/deploy.sh https://raw.githubusercontent.com/Maoqi-zxy/gig-platform/main/deploy/deploy-aliyun-swas.sh

# 添加执行权限
chmod +x /tmp/deploy.sh

# 执行部署
bash /tmp/deploy.sh
```

**脚本会自动完成以下内容：**

| 步骤 | 操作 | 预计时间 |
|------|------|---------|
| 1 | 检查/创建部署目录 | 5 秒 |
| 2 | 安装 Node.js/Nginx/Git | 2-3 分钟 |
| 3 | 部署后端服务 + PM2 | 1-2 分钟 |
| 4 | 构建部署前端 | 2-3 分钟 |
| 5 | 配置 Nginx | 30 秒 |
| 6 | 启动服务 | 10 秒 |

**总计约 6-8 分钟完成**

---

## 三、手动部署（可选）

如果自动脚本失败，可以手动执行以下步骤：

### Step 1: 切换到 admin 用户
```bash
# 以 root 登录后执行
su - admin
cd ~
```

### Step 2: 创建部署目录
```bash
mkdir -p ~/flex-platform/{backend,frontend,logs,pm2}
```

### Step 3: 安装依赖（需要 root 权限）
```bash
# 退出 admin，临时使用 root
exit

# 安装必要工具
yum install -y epel-release
yum install -y git nodejs npm nginx

# 重新切换到 admin
su - admin
```

### Step 4: 部署后端
```bash
cd ~/flex-platform/backend

# 拉取代码
git clone https://github.com/Maoqi-zxy/gig-platform.git .
git checkout v1.0.0-snapshot

# 安装依赖
npm install --production

# 配置环境变量
cat > .env << EOF
NODE_ENV=production
PORT=8081
DATABASE_PATH=/home/admin/flex-platform/backend/gig_platform.db
JWT_SECRET=gig-platform-aliyun-admin-$(date +%Y%m%d%H%M%S)-isolate
CORS_ORIGIN=http://106.14.172.39:8080
EOF

# 安装 PM2
npm install -g pm2

# 启动服务
pm2 start --name gig-api npm -- start
pm2 save
```

### Step 5: 部署前端
```bash
cd ~/flex-platform

# 拉取前端代码
git clone --depth=1 https://github.com/Maoqi-zxy/flexible-work-platform.git frontend-temp
cd frontend-temp

# 安装依赖
npm install

# 配置 API 地址
cat > .env.production << EOF
VITE_API_URL=http://106.14.172.39:8081
EOF

# 构建前端
npm run build

# 移动构建产物
mv dist ../frontend
cd ..
rm -rf frontend-temp
```

### Step 6: 配置 Nginx（需要 root 权限）
```bash
# 退出 admin，使用 root
exit

# 创建 Nginx 配置
cat > /etc/nginx/conf.d/gig-platform.conf << 'EOF'
# 灵活用工平台 - 隔离部署（admin 用户）
server {
    listen 8080;
    server_name 106.14.172.39;
    
    root /home/admin/flex-platform/frontend/dist;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /api-docs {
        proxy_pass http://127.0.0.1:8081/api-docs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    access_log /home/admin/flex-platform/logs/nginx-access.log;
    error_log /home/admin/flex-platform/logs/nginx-error.log;
}
EOF

# 测试配置
nginx -t

# 重启 Nginx
systemctl restart nginx

# 重新切换到 admin
su - admin
```

### Step 7: 配置防火墙
**在阿里云控制台添加规则：**
1. 访问：https://swasnext.console.aliyun.com/servers/cn-shanghai/1735a331a92f46ef9d82abb417c07b04/firewall
2. 添加入站规则：
   - **端口 8080**，协议 TCP，授权对象 `0.0.0.0/0`
   - **端口 8081**，协议 TCP，授权对象 `0.0.0.0/0`

---

## 四、验证部署

```bash
# 检查 PM2 状态
pm2 status

# 检查后端服务
curl http://localhost:8081/api/health

# 检查前端服务
curl http://localhost:8080/

# 检查 Nginx 状态（需要 root）
sudo systemctl status nginx

# 查看 PM2 日志
pm2 logs gig-api
```

**浏览器访问：**
- 前端：`http://106.14.172.39:8080`
- API 文档：`http://106.14.172.39:8081/api-docs`

---

## 五、运维管理

### 重启服务
```bash
# 重启后端（以 admin 用户）
pm2 restart gig-api

# 重启 Nginx（需要 root）
sudo systemctl restart nginx
```

### 查看日志
```bash
# PM2 日志
pm2 logs gig-api

# Nginx 日志
tail -f /home/admin/flex-platform/logs/nginx-access.log
```

### 更新代码
```bash
# 后端更新（以 admin 用户）
cd ~/flex-platform/backend
git pull
pm2 restart gig-api

# 前端更新
cd ~/flex-platform/frontend
git pull
npm install
npm run build

# 重启 Nginx（需要 root）
sudo systemctl restart nginx
```

---

## 六、安全检查清单

- ✅ 使用独立用户 `admin`
- ✅ 使用独立目录 `/home/admin/flex-platform/`
- ✅ 使用独立端口 `8080/8081`
- ✅ 使用 SQLite（无需额外数据库）
- ⚠️ 请配置阿里云防火墙
- ⚠️ 请设置 PM2 开机自启

---

## 七、故障排查

### 问题 1：端口被占用
```bash
# 检查端口占用
netstat -tlnp | grep -E '8080|8081'

# 如果冲突，修改端口
# 后端：编辑 .env 文件，修改 PORT=8081
# 前端：编辑 Nginx 配置，修改 listen 8080
```

### 问题 2：PM2 服务异常
```bash
# 查看 PM2 状态
pm2 status

# 重启服务
pm2 restart gig-api

# 查看日志
pm2 logs gig-api --lines 50
```

### 问题 3：Nginx 启动失败
```bash
# 检查配置
sudo nginx -t

# 查看日志
sudo tail -f /var/log/nginx/error.log

# 检查端口占用
sudo netstat -tlnp | grep :8080
```

### 问题 4：无法访问
```bash
# 1. 检查服务是否运行
pm2 status
sudo systemctl status nginx

# 2. 检查防火墙（阿里云控制台）
# 确认 8080/8081 端口已放行

# 3. 测试本地访问
curl http://localhost:8080/
curl http://localhost:8081/api/health

# 4. 检查 Nginx 配置
sudo cat /etc/nginx/conf.d/gig-platform.conf
```

---

## 八、快速诊断命令

```bash
# 复制粘贴以下命令快速诊断
echo "=== 诊断报告 ==="
echo "当前用户：$(whoami)"
echo "部署目录：/home/admin/flex-platform/"
echo ""
echo "=== PM2 状态 ==="
pm2 status 2>/dev/null || echo "PM2 未安装或服务未启动"
echo ""
echo "=== Nginx 状态 ==="
sudo systemctl status nginx --no-pager 2>/dev/null || echo "Nginx 状态未知"
echo ""
echo "=== 端口监听 ==="
netstat -tlnp 2>/dev/null | grep -E '8080|8081' || echo "端口未监听"
echo ""
echo "=== 磁盘使用 ==="
df -h /home
echo "=================="
```

---

**创建时间**: 2026-03-24  
**版本**: v1.1 (root 登录，admin 部署)  
**部署原则**: 完全隔离，不影响任何现有服务
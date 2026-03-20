const Database = require('better-sqlite3');
const bcrypt = require('bcryptjs');
const path = require('path');

// 初始化数据库
const db = new Database(path.join(__dirname, 'gig_platform.db'));

// 启用外键约束
db.pragma('foreign_keys = ON');

// 创建用户表
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'freelancer', -- 'enterprise' or 'freelancer'
    company_name VARCHAR(100), -- 企业名称（企业用户）
    skills TEXT, -- 技能标签（自由职业者）
    avatar_url VARCHAR(255),
    phone VARCHAR(20),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
`);

// 创建任务表
db.exec(`
  CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50), -- 任务类别
    budget_min DECIMAL(10,2), -- 预算范围
    budget_max DECIMAL(10,2),
    deadline DATETIME, -- 截止时间
    status VARCHAR(20) DEFAULT 'open', -- 'open', 'in_progress', 'completed', 'cancelled'
    enterprise_id INTEGER NOT NULL, -- 发布任务的企业 ID
    freelancer_id INTEGER, -- 接任务的自由职业者 ID
    views INTEGER DEFAULT 0, -- 浏览量
    applications INTEGER DEFAULT 0, -- 申请数
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (enterprise_id) REFERENCES users(id),
    FOREIGN KEY (freelancer_id) REFERENCES users(id)
  )
`);

// 创建任务提交表
db.exec(`
  CREATE TABLE IF NOT EXISTS submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    freelancer_id INTEGER NOT NULL,
    content TEXT NOT NULL, -- 提交内容
    attachment_url VARCHAR(255), -- 附件链接
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    feedback TEXT, -- 审核反馈
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reviewed_at DATETIME,
    FOREIGN KEY (task_id) REFERENCES tasks(id),
    FOREIGN KEY (freelancer_id) REFERENCES users(id)
  )
`);

// 创建申请表
db.exec(`
  CREATE TABLE IF NOT EXISTS applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    freelancer_id INTEGER NOT NULL,
    cover_letter TEXT, -- 求职信
    proposed_budget DECIMAL(10,2), -- 期望报酬
    estimated_days INTEGER, -- 预计完成天数
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    responded_at DATETIME,
    FOREIGN KEY (task_id) REFERENCES tasks(id),
    FOREIGN KEY (freelancer_id) REFERENCES users(id),
    UNIQUE(task_id, freelancer_id) -- 同一任务同一人只能申请一次
  )
`);

// 创建索引
db.exec(`
  CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
  CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category);
  CREATE INDEX IF NOT EXISTS idx_tasks_enterprise ON tasks(enterprise_id);
  CREATE INDEX IF NOT EXISTS idx_applications_task ON applications(task_id);
  CREATE INDEX IF NOT EXISTS idx_submissions_task ON submissions(task_id);
`);

// 创建测试数据
const stmt = db.prepare(`
  INSERT OR IGNORE INTO users (username, email, password_hash, role, company_name, skills)
  VALUES (?, ?, ?, ?, ?, ?)
`);

// 创建测试企业用户
const enterpriseHash = bcrypt.hashSync('enterprise123', 10);
stmt.run('华为技术', 'huawei@example.com', enterpriseHash, 'enterprise', '华为技术有限公司', null);

// 创建测试自由职业者用户
const freelancerHash = bcrypt.hashSync('freelancer123', 10);
stmt.run('设计师小王', 'designer@example.com', freelancerHash, 'freelancer', null, 'UI 设计，平面设计，品牌设计');

// 创建测试任务
const taskStmt = db.prepare(`
  INSERT OR IGNORE INTO tasks (title, description, category, budget_min, budget_max, deadline, status, enterprise_id)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
`);
taskStmt.run('企业官网设计', '需要设计一个现代化的企业官网，包含首页、关于我们、产品展示等页面', '设计', 5000, 10000, '2026-04-20', 'open', 1);
taskStmt.run('微信小程序开发', '开发一个电商类微信小程序，包含商品展示、购物车、订单管理等功能', '开发', 15000, 30000, '2026-05-01', 'open', 1);

console.log('✅ 数据库初始化完成！');
console.log('📊 创建了测试数据：');
console.log('   - 企业用户：华为技术 (huawei@example.com / enterprise123)');
console.log('   - 自由职业者：设计师小王 (designer@example.com / freelancer123)');
console.log('   - 测试任务：2 个');

module.exports = db;
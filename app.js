require('dotenv').config();
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');
const db = require('./database');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// 中间件
app.use(cors());
app.use(express.json());

// Swagger 配置
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: '灵活用工平台 API',
      version: '1.0.0',
      description: '连接企业需求方和自由职业者的任务对接平台',
      contact: {
        name: 'API Support',
        email: 'support@gig-platform.com'
      }
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: '本地开发环境'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    }
  },
  apis: ['./routes/*.js', './app.js']
};

// 手动定义 API 文档（因为 better-sqlite3 是同步的，不方便用 JSDoc）
const swaggerSpec = {
  openapi: '3.0.0',
  info: {
    title: '灵活用工平台 API',
    version: '1.0.0',
    description: `
# 灵活用工平台 API 文档

连接企业需求方和自由职业者的任务对接平台

## 认证方式
所有需要认证的接口需要在 Header 中携带 JWT Token:
\`Authorization: Bearer <your-token>\`

## 测试账号
- 企业用户：huawei@example.com / enterprise123
- 自由职业者：designer@example.com / freelancer123

## 响应格式
所有接口返回统一的 JSON 格式:
\`\`\`json
{
  "success": true,
  "data": {},
  "message": "操作成功"
}
\`\`\`
    `
  },
  servers: [
    {
      url: 'http://localhost:3000',
      description: '本地开发环境'
    }
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT'
      }
    },
    schemas: {
      User: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          username: { type: 'string' },
          email: { type: 'string' },
          role: { type: 'string', enum: ['enterprise', 'freelancer'] },
          company_name: { type: 'string' },
          skills: { type: 'string' },
          avatar_url: { type: 'string' },
          phone: { type: 'string' },
          created_at: { type: 'string', format: 'date-time' }
        }
      },
      Task: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          title: { type: 'string' },
          description: { type: 'string' },
          category: { type: 'string' },
          budget_min: { type: 'number' },
          budget_max: { type: 'number' },
          deadline: { type: 'string', format: 'date-time' },
          status: { type: 'string', enum: ['open', 'in_progress', 'completed', 'cancelled'] },
          enterprise_id: { type: 'integer' },
          freelancer_id: { type: 'integer' },
          views: { type: 'integer' },
          applications: { type: 'integer' },
          created_at: { type: 'string', format: 'date-time' }
        }
      },
      Application: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          task_id: { type: 'integer' },
          freelancer_id: { type: 'integer' },
          cover_letter: { type: 'string' },
          proposed_budget: { type: 'number' },
          estimated_days: { type: 'integer' },
          status: { type: 'string', enum: ['pending', 'accepted', 'rejected'] },
          applied_at: { type: 'string', format: 'date-time' }
        }
      },
      Submission: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          task_id: { type: 'integer' },
          freelancer_id: { type: 'integer' },
          content: { type: 'string' },
          attachment_url: { type: 'string' },
          status: { type: 'string', enum: ['pending', 'approved', 'rejected'] },
          feedback: { type: 'string' },
          submitted_at: { type: 'string', format: 'date-time' },
          reviewed_at: { type: 'string', format: 'date-time' }
        }
      }
    }
  },
  paths: {
    // 认证接口
    '/api/auth/register': {
      post: {
        tags: ['认证'],
        summary: '用户注册',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['username', 'email', 'password', 'role'],
                properties: {
                  username: { type: 'string' },
                  email: { type: 'string' },
                  password: { type: 'string' },
                  role: { type: 'string', enum: ['enterprise', 'freelancer'] },
                  company_name: { type: 'string' },
                  skills: { type: 'string' },
                  phone: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          '201': { description: '注册成功' },
          '400': { description: '参数错误' }
        }
      }
    },
    '/api/auth/login': {
      post: {
        tags: ['认证'],
        summary: '用户登录',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'password'],
                properties: {
                  email: { type: 'string' },
                  password: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          '200': { description: '登录成功，返回 JWT Token' },
          '401': { description: '邮箱或密码错误' }
        }
      }
    },
    // 任务接口
    '/api/tasks': {
      get: {
        tags: ['任务'],
        summary: '获取任务列表（支持分页和筛选）',
        parameters: [
          { name: 'page', in: 'query', schema: { type: 'integer', default: 1 } },
          { name: 'limit', in: 'query', schema: { type: 'integer', default: 10 } },
          { name: 'status', in: 'query', schema: { type: 'string', enum: ['open', 'in_progress', 'completed', 'cancelled'] } },
          { name: 'category', in: 'query', schema: { type: 'string' } }
        ],
        responses: {
          '200': { description: '返回任务列表' }
        }
      },
      post: {
        tags: ['任务'],
        summary: '发布新任务（需要企业认证）',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['title', 'description', 'category', 'budget_min', 'budget_max'],
                properties: {
                  title: { type: 'string' },
                  description: { type: 'string' },
                  category: { type: 'string' },
                  budget_min: { type: 'number' },
                  budget_max: { type: 'number' },
                  deadline: { type: 'string', format: 'date' }
                }
              }
            }
          }
        },
        responses: {
          '201': { description: '任务发布成功' },
          '401': { description: '未认证' },
          '403': { description: '仅限企业用户' }
        }
      }
    },
    '/api/tasks/{id}': {
      get: {
        tags: ['任务'],
        summary: '获取任务详情',
        parameters: [
          { name: 'id', in: 'path', required: true, schema: { type: 'integer' } }
        ],
        responses: {
          '200': { description: '返回任务详情' },
          '404': { description: '任务不存在' }
        }
      },
      put: {
        tags: ['任务'],
        summary: '更新任务（仅任务发布者）',
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: 'id', in: 'path', required: true, schema: { type: 'integer' } }
        ],
        responses: {
          '200': { description: '更新成功' },
          '403': { description: '无权修改' },
          '404': { description: '任务不存在' }
        }
      },
      delete: {
        tags: ['任务'],
        summary: '删除任务（仅任务发布者）',
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: 'id', in: 'path', required: true, schema: { type: 'integer' } }
        ],
        responses: {
          '200': { description: '删除成功' },
          '403': { description: '无权删除' },
          '404': { description: '任务不存在' }
        }
      }
    },
    '/api/tasks/{id}/apply': {
      post: {
        tags: ['申请'],
        summary: '申请任务（自由职业者）',
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: 'id', in: 'path', required: true, schema: { type: 'integer' } }
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  cover_letter: { type: 'string' },
                  proposed_budget: { type: 'number' },
                  estimated_days: { type: 'integer' }
                }
              }
            }
          }
        },
        responses: {
          '201': { description: '申请成功' },
          '400': { description: '不能申请自己发布的任务' },
          '409': { description: '已申请过该任务' }
        }
      }
    },
    '/api/tasks/{id}/submissions': {
      post: {
        tags: ['提交'],
        summary: '提交任务成果',
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: 'id', in: 'path', required: true, schema: { type: 'integer' } }
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['content'],
                properties: {
                  content: { type: 'string' },
                  attachment_url: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          '201': { description: '提交成功' }
        }
      },
      get: {
        tags: ['提交'],
        summary: '查看任务提交列表（仅任务发布者）',
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: 'id', in: 'path', required: true, schema: { type: 'integer' } }
        ],
        responses: {
          '200': { description: '返回提交列表' }
        }
      }
    },
    '/api/submissions/{id}/review': {
      post: {
        tags: ['提交'],
        summary: '审核提交成果',
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: 'id', in: 'path', required: true, schema: { type: 'integer' } }
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['status', 'feedback'],
                properties: {
                  status: { type: 'string', enum: ['approved', 'rejected'] },
                  feedback: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          '200': { description: '审核成功' }
        }
      }
    },
    // 个人中心
    '/api/profile': {
      get: {
        tags: ['个人中心'],
        summary: '获取当前用户信息',
        security: [{ bearerAuth: [] }],
        responses: {
          '200': { description: '返回用户信息' }
        }
      },
      put: {
        tags: ['个人中心'],
        summary: '更新用户信息',
        security: [{ bearerAuth: [] }],
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  username: { type: 'string' },
                  phone: { type: 'string' },
                  avatar_url: { type: 'string' },
                  skills: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          '200': { description: '更新成功' }
        }
      }
    },
    '/api/my/tasks': {
      get: {
        tags: ['个人中心'],
        summary: '我发布的任务（企业）/ 我申请的任务（自由职业者）',
        security: [{ bearerAuth: [] }],
        responses: {
          '200': { description: '返回任务列表' }
        }
      }
    },
    '/api/my/applications': {
      get: {
        tags: ['个人中心'],
        summary: '我的申请列表（自由职业者）',
        security: [{ bearerAuth: [] }],
        responses: {
          '200': { description: '返回申请列表' }
        }
      }
    }
  }
};

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// 认证中间件
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: '未提供认证令牌' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: '无效的认证令牌' });
  }
};

// ========== 认证接口 ==========

/**
 * @route POST /api/auth/register
 * @group 认证
 * @param {string} username.body.required - 用户名
 * @param {string} email.body.required - 邮箱
 * @param {string} password.body.required - 密码
 * @param {string} role.body.required - 角色 (enterprise/freelancer)
 * @returns {object} 201 - 注册成功
 */
app.post('/api/auth/register', (req, res) => {
  const { username, email, password, role, company_name, skills, phone } = req.body;

  if (!username || !email || !password || !role) {
    return res.status(400).json({ success: false, message: '必填字段缺失' });
  }

  if (!['enterprise', 'freelancer'].includes(role)) {
    return res.status(400).json({ success: false, message: '角色类型错误' });
  }

  try {
    // 检查邮箱是否已存在
    const existingEmail = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existingEmail) {
      return res.status(400).json({ success: false, message: '邮箱已被注册' });
    }

    // 检查用户名是否已存在
    const existingUser = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
    if (existingUser) {
      return res.status(400).json({ success: false, message: '用户名已被占用' });
    }

    // 加密密码
    const passwordHash = bcrypt.hashSync(password, 10);

    // 处理 skills：如果是数组则转换为逗号分隔的字符串
    const skillsStr = Array.isArray(skills) ? skills.join(',') : (skills || '');

    // 插入用户
    const result = db.prepare(`
      INSERT INTO users (username, email, password_hash, role, company_name, skills, phone)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(username, email, passwordHash, role, company_name, skillsStr, phone);

    // 生成 JWT Token
    const token = jwt.sign(
      { id: result.lastInsertRowid, email, role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.lastInsertRowid,
        username,
        email,
        role,
        token
      },
      message: '注册成功'
    });
  } catch (error) {
    console.error('注册错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route POST /api/auth/login
 * @group 认证
 * @param {string} email.body.required - 邮箱
 * @param {string} password.body.required - 密码
 * @returns {object} 200 - 登录成功
 */
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ success: false, message: '邮箱和密码不能为空' });
  }

  try {
    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    if (!user) {
      return res.status(401).json({ success: false, message: '邮箱或密码错误' });
    }

    const isValid = bcrypt.compareSync(password, user.password_hash);
    if (!isValid) {
      return res.status(401).json({ success: false, message: '邮箱或密码错误' });
    }

    // 生成 JWT Token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          role: user.role,
          company_name: user.company_name,
          skills: user.skills,
          avatar_url: user.avatar_url,
          phone: user.phone
        }
      },
      message: '登录成功'
    });
  } catch (error) {
    console.error('登录错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

// ========== 任务接口 ==========

/**
 * @route GET /api/tasks
 * @group 任务
 * @param {number} page.query - 页码 (默认 1)
 * @param {number} limit.query - 每页数量 (默认 10)
 * @param {string} status.query - 状态筛选
 * @param {string} category.query - 类别筛选
 * @returns {object} 200 - 任务列表
 */
app.get('/api/tasks', (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const { status, category } = req.query;

  const offset = (page - 1) * limit;

  let whereClause = 'WHERE 1=1';
  const params = [];

  if (status) {
    whereClause += ' AND status = ?';
    params.push(status);
  }

  if (category) {
    whereClause += ' AND category = ?';
    params.push(category);
  }

  try {
    // 查询总数
    const totalStmt = db.prepare(`SELECT COUNT(*) as total FROM tasks ${whereClause}`);
    const { total } = totalStmt.get(...params);

    // 查询数据
    const tasks = db.prepare(`
      SELECT t.*, u.username as enterprise_name, u.company_name
      FROM tasks t
      JOIN users u ON t.enterprise_id = u.id
      ${whereClause}
      ORDER BY t.created_at DESC
      LIMIT ? OFFSET ?
    `).all(...params, limit, offset);

    res.json({
      success: true,
      data: {
        tasks,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('查询任务错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route GET /api/tasks/:id
 * @group 任务
 * @param {number} id.path.required - 任务 ID
 * @returns {object} 200 - 任务详情
 */
app.get('/api/tasks/:id', (req, res) => {
  const { id } = req.params;

  try {
    // 增加浏览量
    db.prepare('UPDATE tasks SET views = views + 1 WHERE id = ?').run(id);

    const task = db.prepare(`
      SELECT t.*, u.username as enterprise_name, u.company_name
      FROM tasks t
      JOIN users u ON t.enterprise_id = u.id
      WHERE t.id = ?
    `).get(id);

    if (!task) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    res.json({ success: true, data: task });
  } catch (error) {
    console.error('查询任务详情错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route POST /api/tasks
 * @group 任务
 * @security Bearer
 * @returns {object} 201 - 发布成功
 */
app.post('/api/tasks', authMiddleware, (req, res) => {
  const { title, description, category, budget_min, budget_max, deadline } = req.body;

  if (!title || !description || !category || !budget_min || !budget_max) {
    return res.status(400).json({ success: false, message: '必填字段缺失' });
  }

  if (req.user.role !== 'enterprise') {
    return res.status(403).json({ success: false, message: '仅限企业用户发布任务' });
  }

  try {
    const result = db.prepare(`
      INSERT INTO tasks (title, description, category, budget_min, budget_max, deadline, enterprise_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(title, description, category, budget_min, budget_max, deadline, req.user.id);

    res.status(201).json({
      success: true,
      data: { id: result.lastInsertRowid },
      message: '任务发布成功'
    });
  } catch (error) {
    console.error('发布任务错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route PUT /api/tasks/:id
 * @group 任务
 * @security Bearer
 * @param {number} id.path.required - 任务 ID
 * @returns {object} 200 - 更新成功
 */
app.put('/api/tasks/:id', authMiddleware, (req, res) => {
  const { id } = req.params;
  const { title, description, category, budget_min, budget_max, deadline, status } = req.body;

  try {
    const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);
    if (!task) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    if (task.enterprise_id !== req.user.id) {
      return res.status(403).json({ success: false, message: '无权修改此任务' });
    }

    db.prepare(`
      UPDATE tasks
      SET title = ?, description = ?, category = ?, budget_min = ?, budget_max = ?, deadline = ?, status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(title || task.title, description || task.description, category || task.category,
           budget_min || task.budget_min, budget_max || task.budget_max,
           deadline || task.deadline, status || task.status, id);

    res.json({ success: true, message: '任务更新成功' });
  } catch (error) {
    console.error('更新任务错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route DELETE /api/tasks/:id
 * @group 任务
 * @security Bearer
 * @param {number} id.path.required - 任务 ID
 * @returns {object} 200 - 删除成功
 */
app.delete('/api/tasks/:id', authMiddleware, (req, res) => {
  const { id } = req.params;

  try {
    const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);
    if (!task) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    if (task.enterprise_id !== req.user.id) {
      return res.status(403).json({ success: false, message: '无权删除此任务' });
    }

    db.prepare('DELETE FROM tasks WHERE id = ?').run(id);
    res.json({ success: true, message: '任务已删除' });
  } catch (error) {
    console.error('删除任务错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

// ========== 申请接口 ==========

/**
 * @route POST /api/tasks/:id/apply
 * @group 申请
 * @security Bearer
 * @param {number} id.path.required - 任务 ID
 * @returns {object} 201 - 申请成功
 */
app.post('/api/tasks/:id/apply', authMiddleware, (req, res) => {
  const { id } = req.params;
  const { cover_letter, proposed_budget, estimated_days } = req.body;

  if (req.user.role !== 'freelancer') {
    return res.status(403).json({ success: false, message: '仅限自由职业者申请任务' });
  }

  try {
    const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);
    if (!task) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    if (task.enterprise_id === req.user.id) {
      return res.status(400).json({ success: false, message: '不能申请自己发布的任务' });
    }

    // 检查是否已申请
    const existing = db.prepare('SELECT id FROM applications WHERE task_id = ? AND freelancer_id = ?').get(id, req.user.id);
    if (existing) {
      return res.status(409).json({ success: false, message: '已申请过该任务' });
    }

    db.prepare(`
      INSERT INTO applications (task_id, freelancer_id, cover_letter, proposed_budget, estimated_days)
      VALUES (?, ?, ?, ?, ?)
    `).run(id, req.user.id, cover_letter, proposed_budget, estimated_days);

    // 更新任务申请数
    db.prepare('UPDATE tasks SET applications = applications + 1 WHERE id = ?').run(id);

    res.status(201).json({ success: true, message: '申请成功' });
  } catch (error) {
    console.error('申请任务错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

// ========== 提交接口 ==========

/**
 * @route POST /api/tasks/:id/submissions
 * @group 提交
 * @security Bearer
 * @param {number} id.path.required - 任务 ID
 * @returns {object} 201 - 提交成功
 */
app.post('/api/tasks/:id/submissions', authMiddleware, (req, res) => {
  const { id } = req.params;
  const { content, attachment_url } = req.body;

  if (!content) {
    return res.status(400).json({ success: false, message: '提交内容不能为空' });
  }

  if (req.user.role !== 'freelancer') {
    return res.status(403).json({ success: false, message: '仅限自由职业者提交成果' });
  }

  try {
    const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);
    if (!task) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    // 检查是否已提交
    const existing = db.prepare('SELECT id FROM submissions WHERE task_id = ? AND freelancer_id = ?').get(id, req.user.id);
    if (existing) {
      return res.status(409).json({ success: false, message: '已提交过成果' });
    }

    db.prepare(`
      INSERT INTO submissions (task_id, freelancer_id, content, attachment_url)
      VALUES (?, ?, ?, ?)
    `).run(id, req.user.id, content, attachment_url);

    res.status(201).json({ success: true, message: '提交成功' });
  } catch (error) {
    console.error('提交成果错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route GET /api/tasks/:id/submissions
 * @group 提交
 * @security Bearer
 * @param {number} id.path.required - 任务 ID
 * @returns {object} 200 - 提交列表
 */
app.get('/api/tasks/:id/submissions', authMiddleware, (req, res) => {
  const { id } = req.params;

  try {
    const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);
    if (!task) {
      return res.status(404).json({ success: false, message: '任务不存在' });
    }

    if (task.enterprise_id !== req.user.id) {
      return res.status(403).json({ success: false, message: '无权查看此任务的提交' });
    }

    const submissions = db.prepare(`
      SELECT s.*, u.username as freelancer_name, u.skills
      FROM submissions s
      JOIN users u ON s.freelancer_id = u.id
      WHERE s.task_id = ?
      ORDER BY s.submitted_at DESC
    `).all(id);

    res.json({ success: true, data: submissions });
  } catch (error) {
    console.error('查询提交错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route POST /api/submissions/:id/review
 * @group 提交
 * @security Bearer
 * @param {number} id.path.required - 提交 ID
 * @returns {object} 200 - 审核成功
 */
app.post('/api/submissions/:id/review', authMiddleware, (req, res) => {
  const { id } = req.params;
  const { status, feedback } = req.body;

  if (!['approved', 'rejected'].includes(status)) {
    return res.status(400).json({ success: false, message: '审核状态无效' });
  }

  if (req.user.role !== 'enterprise') {
    return res.status(403).json({ success: false, message: '仅限企业用户审核' });
  }

  try {
    const submission = db.prepare('SELECT * FROM submissions WHERE id = ?').get(id);
    if (!submission) {
      return res.status(404).json({ success: false, message: '提交不存在' });
    }

    const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(submission.task_id);
    if (!task || task.enterprise_id !== req.user.id) {
      return res.status(403).json({ success: false, message: '无权审核此提交' });
    }

    db.prepare(`
      UPDATE submissions
      SET status = ?, feedback = ?, reviewed_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(status, feedback, id);

    // 如果审核通过，更新任务状态
    if (status === 'approved') {
      db.prepare(`
        UPDATE tasks
        SET status = 'in_progress', freelancer_id = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `).run(submission.freelancer_id, submission.task_id);
    }

    res.json({ success: true, message: '审核成功' });
  } catch (error) {
    console.error('审核提交错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

// ========== 个人中心接口 ==========

/**
 * @route GET /api/profile
 * @group 个人中心
 * @security Bearer
 * @returns {object} 200 - 用户信息
 */
app.get('/api/profile', authMiddleware, (req, res) => {
  try {
    const user = db.prepare(`
      SELECT id, username, email, role, company_name, skills, avatar_url, phone, created_at
      FROM users
      WHERE id = ?
    `).get(req.user.id);

    if (!user) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }

    res.json({ success: true, data: user });
  } catch (error) {
    console.error('查询用户信息错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route PUT /api/profile
 * @group 个人中心
 * @security Bearer
 * @returns {object} 200 - 更新成功
 */
app.put('/api/profile', authMiddleware, (req, res) => {
  const { username, phone, avatar_url, skills } = req.body;

  try {
    // 处理 skills：如果是数组则转换为逗号分隔的字符串
    const skillsStr = Array.isArray(skills) ? skills.join(',') : (skills || '');
    
    db.prepare(`
      UPDATE users
      SET username = ?, phone = ?, avatar_url = ?, skills = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(username, phone, avatar_url, skillsStr, req.user.id);

    res.json({ success: true, message: '个人信息更新成功' });
  } catch (error) {
    console.error('更新用户信息错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route GET /api/my/tasks
 * @group 个人中心
 * @security Bearer
 * @returns {object} 200 - 我的任务列表
 */
app.get('/api/my/tasks', authMiddleware, (req, res) => {
  try {
    let tasks;
    if (req.user.role === 'enterprise') {
      // 企业：获取我发布的任务
      tasks = db.prepare(`
        SELECT t.*, 
          (SELECT COUNT(*) FROM applications WHERE task_id = t.id) as application_count,
          (SELECT COUNT(*) FROM submissions WHERE task_id = t.id) as submission_count
        FROM tasks t
        WHERE t.enterprise_id = ?
        ORDER BY t.created_at DESC
      `).all(req.user.id);
    } else {
      // 自由职业者：获取我申请/接手的任务
      tasks = db.prepare(`
        SELECT DISTINCT t.*, u.username as enterprise_name, u.company_name
        FROM tasks t
        JOIN users u ON t.enterprise_id = u.id
        LEFT JOIN applications a ON t.id = a.task_id
        WHERE t.freelancer_id = ? OR a.freelancer_id = ?
        ORDER BY t.created_at DESC
      `).all(req.user.id, req.user.id);
    }

    res.json({ success: true, data: tasks });
  } catch (error) {
    console.error('查询我的任务错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

/**
 * @route GET /api/my/applications
 * @group 个人中心
 * @security Bearer
 * @returns {object} 200 - 我的申请列表
 */
app.get('/api/my/applications', authMiddleware, (req, res) => {
  if (req.user.role !== 'freelancer') {
    return res.status(403).json({ success: false, message: '仅限自由职业者' });
  }

  try {
    const applications = db.prepare(`
      SELECT a.*, t.title as task_title, t.status as task_status,
             u.username as enterprise_name, u.company_name
      FROM applications a
      JOIN tasks t ON a.task_id = t.id
      JOIN users u ON t.enterprise_id = u.id
      WHERE a.freelancer_id = ?
      ORDER BY a.applied_at DESC
    `).all(req.user.id);

    res.json({ success: true, data: applications });
  } catch (error) {
    console.error('查询我的申请错误:', error);
    res.status(500).json({ success: false, message: '服务器错误' });
  }
});

// 启动服务
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║           🚀 灵活用工平台后端服务已启动                    ║
╠═══════════════════════════════════════════════════════════╣
║  服务地址：http://0.0.0.0:${PORT} (局域网可访问)                            
║  API 文档：http://0.0.0.0:${PORT}/api-docs                   
║                                                           ║
║  技术栈: Node.js + Express + SQLite + JWT                 ║
║  数据库：./gig_platform.db                                ║
╚═══════════════════════════════════════════════════════════╝
  `);
});

// ========== 健康检查端点 (用于 Railway 部署) ==========
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

module.exports = app;
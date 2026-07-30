# 企业级 DevOps 平台 Codex 任务文档 V3.0

## 项目定位

构建一个前后端分离企业级 DevOps 平台：

- 后端：Go + Gin
- 前端：Vue3 + TypeScript + Element Plus
- 数据库：PostgreSQL
- CI：Jenkins + Tekton
- CD：Argo CD + GitOps
- 发布：Argo Rollouts Canary / Blue-Green
- 运行：Kubernetes

---

# Codex 通用执行规则

每个 Task 执行前必须：

1. 检查前置文件、目录和工具。
2. 检查 Git 是否存在未提交修改。
3. 条件不满足时停止执行，不创建、不修改文件。
4. 不写真实密码、Token、私钥、kubeconfig。
5. 不修改任务范围外文件。
6. 生成代码必须可编译、可验证。
7. 完成后输出验证命令。

---

# Step 16 后端 Go 项目骨架

## 检查

```bash
test -d backend
test -f docs/variables.md
command -v go
git status --short
```

## Prompt

```text
生成 backend Go 项目骨架。

技术：
Go 1.22+
Gin

生成：
backend/cmd/server/main.go
backend/internal/config
backend/internal/router
backend/internal/middleware
backend/internal/handler
backend/configs/config.example.yaml
backend/go.mod

要求：
- 提供 healthz、readyz接口
- 支持配置加载
- 支持优雅关闭
- 不包含真实配置
- 可 go test
```

---

# Step 17 后端 API 模块

## 检查

```bash
test -f backend/go.mod
test -d backend/internal
```

## Prompt

```text
生成 DevOps 平台 API 模块。

包含：
- 应用管理
- 流水线管理
- 发布管理
- 审批管理
- 审计管理
- Webhook 接收

接口：
GET /api/apps
POST /api/pipelines/trigger
GET /api/pipelines/:id
POST /api/releases
POST /api/releases/:id/promote
POST /api/releases/:id/rollback
GET /api/audit-logs

要求：
Handler + Service + DTO 分层。
先使用接口设计，不直接连接外部系统。
```

---

# Step 18 数据库模型

生成：

```text
backend/internal/model
backend/internal/repository
backend/internal/database
backend/migrations
```

数据库：PostgreSQL

表：

```text
apps
environments
pipelines
releases
approvals
audit_logs
gitops_commits
users
```

要求：

- GORM
- migration SQL
- Repository CRUD
- 不包含真实数据库密码

---

# Step 19 外部系统 Client

生成：

```text
backend/internal/client/

jenkins
tekton
argocd
harbor
git
kubernetes
prometheus
```

要求：

- 使用 interface
- 支持 mock
- 不保存 Token
- 可替换真实实现

---

# Step 20 后端业务 Service

生成：

```text
WebhookService
PipelineService
GitOpsService
ReleaseService
ApprovalService
AuditService
```

要求：

- 调用 client 层
- 实现发布流程
- 实现审批流程
- 实现审计记录

---

# Step 21 后端工程化

生成：

```text
backend/Dockerfile
backend/Makefile
backend/api/openapi.yaml
backend/.dockerignore
```

要求：

- 多阶段 Docker 构建
- 非 root 用户运行
- OpenAPI 文档
- make test/build/fmt

验证：

```bash
cd backend
go test ./...
go build ./...
```

---

# Step 22 前端 Vue3 项目

检查：

```bash
command -v node
command -v pnpm
```

生成：

```text
frontend/
 ├── src/
 ├── router
 ├── store
 ├── api
 ├── layouts
 └── pages
```

技术：

- Vue3
- TypeScript
- Vite
- Element Plus
- Pinia
- Axios

---

# Step 23 前端业务页面

生成页面：

```text
应用管理
流水线管理
发布管理
审批中心
审计日志
系统设置
```

要求：

- API 独立封装
- 表格
- Loading
- 错误处理
- 发布详情支持 promote / rollback

---

# Step 24 前端 Docker 化

生成：

```text
frontend/Dockerfile
frontend/nginx.conf
```

要求：

- Node build
- Nginx运行
- Vue history支持
- /api代理后端Service

---

# Step 25 平台部署与CI

生成：

## Helm

```text
deploy/helm/devops-platform
```

包含：

- backend Deployment
- frontend Deployment
- Service
- Ingress
- ConfigMap
- Secret 示例

## Jenkins

要求：

- backend 修改只构建 backend
- frontend 修改只构建 frontend
- 自动测试
- Docker build
- Trivy扫描
- Harbor推送
- GitOps更新

## Tekton

要求：

- Pipeline
- Task
- Image build
- Security scan
- GitOps update

---

# 最终验收

## Backend

```bash
cd backend
go test ./...
go build ./...
```

## Frontend

```bash
cd frontend
pnpm install
pnpm build
```

## Helm

```bash
helm lint deploy/helm/devops-platform
helm template devops-platform deploy/helm/devops-platform
```

---

# 执行顺序

```text
16 后端骨架
17 API模块
18 数据库
19 外部Client
20 Service业务层
21 后端工程化
22 前端骨架
23 前端页面
24 前端Docker
25 Helm + Jenkins + Tekton
```

每完成一步：

```bash
git add .
git commit -m "feat: complete task xx"
```


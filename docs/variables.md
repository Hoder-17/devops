# 全局变量规范

本文档定义 CI/CD + GitOps 平台在 Jenkins、Tekton、脚本、Helm values、Argo CD 和安全扫描流程中统一使用的标准变量。所有流水线和脚本应优先读取这些变量，避免同一含义在不同文件中使用不同命名。

## 命名原则

- 变量名统一使用大写字母和下划线，例如 `APP_NAME`。
- 环境名称统一使用 `dev`、`test`、`staging`、`prod`。
- 镜像 Tag 禁止使用 `latest`，推荐使用 Git commit short SHA、Release 版本号或 Hotfix 标识。
- 敏感信息不得写入 Git，必须通过 Jenkins Credentials、Tekton Secret、Kubernetes Secret、External Secrets 或 Vault 注入。

## 标准变量

| 变量名 | 必填 | 示例值 | 说明 | 存储要求 |
|---|---|---|---|---|
| `APP_NAME` | 是 | `order-service` | 应用名称，用于镜像、GitOps 路径、Kubernetes label 和发布记录。 | 可提交到 Git |
| `APP_ENV` | 是 | `dev` | 应用部署环境，取值为 `dev`、`test`、`staging`、`prod`。如脚本使用 `DEPLOY_ENV`，应与该变量保持一致。 | 可提交到 Git |
| `IMAGE_REPOSITORY` | 是 | `harbor.company.com/business/order-service` | 完整镜像仓库路径，不包含 Tag。 | 可提交到 Git，内部私有地址可按团队策略处理 |
| `IMAGE_TAG` | 是 | `abc1234` | 镜像 Tag，必须是可追踪版本，不允许使用 `latest`。 | 可提交到 Git |
| `HARBOR_URL` | 是 | `https://harbor.company.com` | Harbor 服务地址，只表示访问入口，不包含账号或密码。 | 可提交到 Git |
| `GITOPS_REPO_URL` | 是 | `git@git.company.com:devops/gitops-repo.git` | GitOps 仓库地址，用于更新期望状态。 | 可提交到 Git，私有仓库认证信息必须放入 Secret 或 Credentials |
| `GITOPS_BRANCH` | 是 | `main` | GitOps 仓库目标分支。生产环境建议启用分支保护和审批。 | 可提交到 Git |
| `GITOPS_APP_PATH` | 是 | `apps/order-service/overlays/dev` | GitOps 仓库中应用环境配置路径。 | 可提交到 Git |
| `ARGOCD_NAMESPACE` | 是 | `argocd` | Argo CD 控制面所在 Kubernetes namespace。 | 可提交到 Git |
| `K8S_NAMESPACE` | 是 | `order-service-dev` | 应用部署到的 Kubernetes namespace。 | 可提交到 Git |
| `SONAR_HOST_URL` | 否 | `https://sonar.company.com` | SonarQube 服务地址。为空时可跳过 SonarQube 扫描。 | 可提交到 Git |
| `SONAR_TOKEN` | 否 | 通过 Secret 注入 | SonarQube 认证 Token，用于 CI 扫描上传结果。 | 必须放入 Secret 或 Credentials |

## 可提交到 Git 的变量

以下变量不应包含认证信息，可写入 `.env.example`、Helm values、Pipeline 参数示例或文档：

- `APP_NAME`
- `APP_ENV`
- `IMAGE_REPOSITORY`
- `IMAGE_TAG`
- `HARBOR_URL`
- `GITOPS_REPO_URL`
- `GITOPS_BRANCH`
- `GITOPS_APP_PATH`
- `ARGOCD_NAMESPACE`
- `K8S_NAMESPACE`
- `SONAR_HOST_URL`

注意：如果企业策略认为内部域名、仓库地址或命名空间属于敏感资产信息，可以只在私有仓库中保留，公开示例中应使用占位符。

## 必须放入 Secret 或 Credentials 的变量

以下变量或相关凭据不得提交到 Git：

- `SONAR_TOKEN`
- Harbor 用户名、密码、Robot Account Token
- GitOps 仓库 SSH 私钥、Deploy Key、Access Token
- kubeconfig、Kubernetes ServiceAccount Token
- Argo CD 登录密码、API Token
- Cosign 私钥、云厂商 Access Key、数据库密码

推荐存储位置：

| 场景 | 推荐方式 |
|---|---|
| Jenkins 流水线 | Jenkins Credentials |
| Tekton Pipeline | Kubernetes Secret 或 External Secrets |
| Kubernetes 运行时 | Kubernetes Secret、External Secrets 或 Vault |
| 企业统一密钥管理 | Vault 或云厂商 Secret Manager |

## 镜像 Tag 规则

禁止：

```text
IMAGE_TAG=latest
```

推荐：

```text
普通提交：IMAGE_TAG=${GIT_COMMIT_SHA}
Release：IMAGE_TAG=${VERSION}-${GIT_COMMIT_SHA}
Hotfix：IMAGE_TAG=hotfix-${DATE}-${GIT_COMMIT_SHA}
```

## 示例

```env
APP_NAME=order-service
APP_ENV=dev
IMAGE_REPOSITORY=harbor.company.com/business/order-service
IMAGE_TAG=abc1234
HARBOR_URL=https://harbor.company.com
GITOPS_REPO_URL=git@git.company.com:devops/gitops-repo.git
GITOPS_BRANCH=main
GITOPS_APP_PATH=apps/order-service/overlays/dev
ARGOCD_NAMESPACE=argocd
K8S_NAMESPACE=order-service-dev
SONAR_HOST_URL=https://sonar.company.com
SONAR_TOKEN=${SONAR_TOKEN}
```

`SONAR_TOKEN` 在示例中只允许作为环境变量引用，真实值必须由 CI/CD 平台或 Secret 管理系统注入。

## 本地校验命令

```bash
git status
git diff -- docs/variables.md
```

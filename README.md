# DevOps GitOps 平台模板

本仓库用于沉淀企业级 CI/CD 与 GitOps 平台工程模板，覆盖 Jenkins、Tekton、Helm、Kubernetes Manifest、Argo CD、Argo Rollouts、安全扫描和可观测性等模块。仓库目标是提供一套可运行、可审查、可逐步落地的 DevOps 基础设施代码，而不是把真实环境密钥或集群访问凭据写入 Git。

## 目录说明

| 目录 | 用途 |
|---|---|
| `docs/` | 平台任务包、架构说明、发布策略和故障排查等文档。 |
| `ci-jenkins/` | Jenkins Pipeline、共享库和多语言构建示例。 |
| `ci-tekton/` | Tekton Task、Pipeline、Trigger、ServiceAccount 和示例 PipelineRun。 |
| `gitops-repo/` | GitOps 仓库结构示例，按应用和环境管理 Kubernetes 期望状态。 |
| `helm-charts/` | 可复用 Helm Chart，用于应用部署模板化。 |
| `argocd/` | Argo CD Application、AppProject、环境同步策略等配置。 |
| `k8s-manifests/` | Kubernetes 原生 Manifest 示例和基础资源定义。 |
| `rollout/` | Argo Rollouts Canary、Blue-Green 和 AnalysisTemplate 配置。 |
| `scripts/` | 本地校验、辅助生成、镜像或 GitOps 更新相关脚本。 |
| `security/` | 安全扫描、准入策略、Secret 管理示例和合规配置。 |
| `observability/` | Prometheus、Grafana、日志、链路追踪和告警相关配置。 |

## 建议执行顺序

1. 阅读 `docs/codex_devops_gitops_task_package_v2.md`，确认目标架构、变量规范、环境分层和安全边界。
2. 先完善 `security/` 中的凭据引用方式和扫描策略，确保敏感信息只通过受控渠道注入。
3. 配置 `ci-jenkins/` 或 `ci-tekton/`，选择适合团队的 CI 引擎完成测试、构建、扫描和镜像推送。
4. 使用 `helm-charts/` 和 `k8s-manifests/` 定义应用基础部署模板。
5. 在 `gitops-repo/` 中按 `apps/{service}/overlays/{env}` 与 `clusters/{env}` 组织多环境期望状态。
6. 配置 `argocd/`，建议 `dev`、`test` 可自动同步，`staging`、`prod` 使用人工审批或受控同步。
7. 配置 `rollout/`，为核心服务启用 Canary 或 Blue-Green，并接入 Prometheus 指标分析。
8. 配置 `observability/`，补齐指标、日志、链路追踪和告警闭环。
9. 使用 `scripts/` 中的本地校验命令检查 YAML、Helm Chart、脚本权限和目录结构。

## 变量规范

`docs/variables.md` 是 Jenkins、Tekton、脚本、Helm values、Argo CD 和安全扫描流程的唯一变量契约。新增配置必须使用 `APP_ENV`、`IMAGE_REPOSITORY`、`GITOPS_BRANCH` 和 `GITOPS_APP_PATH` 等标准变量；迁移期仅由入口脚本兼容 `DEPLOY_ENV` 和 `IMAGE_NAME`，且标准变量与别名的冲突必须作为配置错误处理。

## 安全注意事项

- 不要把真实 Token、密码、kubeconfig、Harbor 密码、Git 私钥或云厂商 Access Key 写入代码、文档、示例文件或提交历史。
- CI/CD 凭据应通过 Jenkins Credentials、Tekton Secret、Kubernetes Secret、External Secrets 或 Vault 引用。
- 示例 Secret 文件只能保留占位符，不能包含真实可用值。
- 镜像构建应优先使用 BuildKit、kaniko 或 buildah，避免在共享集群中无边界使用 Docker-in-Docker。
- 生产环境同步应保留审批、审计和回滚路径，不建议默认自动发布到 `prod`。
- 所有部署命令在执行前都应先进行本地校验和代码评审，避免直接对集群执行未审查变更。

## 本地校验命令

```powershell
git status
ls -R
```

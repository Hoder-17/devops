# 企业级 CI/CD + GitOps 平台 Codex 逐文件代码任务包 V2.0

> 适用场景：GitHub / Gitee / 未来自建 Git 仓库，多语言项目 Java / Go / Python / Rust / Vue / React，统一构建并部署到多 Kubernetes 集群，使用 Argo CD 多环境 GitOps 和 Argo Rollouts 实现 Canary / Blue-Green 灰度发布。

---

## 0. 本次检查结论

上一版“逐文件代码任务包”整体方向正确，但如果直接交给 Codex 生成代码，存在一些容易导致落地偏差的问题。本版已经修正并补充。

### 0.1 已发现并修正的问题

| 序号 | 原问题 | 风险 | 本版修正 |
|---|---|---|---|
| 1 | Jenkins 示例里用 `mvn test || go test || pytest` 这种串联命令 | 会导致语言判断不准确，也可能掩盖失败 | 改为独立语言检测 + 分支化执行 |
| 2 | Tekton 只描述 Pipeline，缺少 Trigger、Secret、Workspace、ServiceAccount | 无法完整触发和认证 | 补齐 Tekton Triggers、ServiceAccount、Secret、Workspace 任务 |
| 3 | Argo Rollouts 指标回滚描述不够具体 | Canary 自动回滚难以实现 | 明确使用 Prometheus AnalysisTemplate |
| 4 | GitOps 仓库结构不够细 | 多服务、多环境容易混乱 | 改为 `apps/{service}/overlays/{env}` + `clusters/{env}` 标准结构 |
| 5 | 生产环境同步策略未细化 | 可能自动发布到生产 | 明确 dev/test 自动同步，staging/prod 手动审批同步 |
| 6 | Docker 构建方式未区分 Jenkins 与 Tekton | DIND 有安全风险 | Jenkins 可用 BuildKit/kaniko，Tekton 使用 kaniko/buildah |
| 7 | Secret 管理缺少边界 | 密钥可能写入 Git 或日志 | 统一要求 Vault / External Secrets / CI Credentials，不允许明文入库 |
| 8 | 缺少执行顺序 | Codex 容易先生成依赖文件，导致上下文不完整 | 增加严格生成顺序和验收命令 |
| 9 | 缺少统一变量规范 | 文件之间参数不一致 | 增加全局变量、命名规则、镜像 Tag 规则 |
| 10 | 缺少 README / env 示例 | 团队无法快速使用 | 新增 README、`.env.example`、Makefile 任务 |

### 0.2 最终结论

本版文档已经可以作为 Codex / Cursor / Claude Code 的工程输入文档使用。建议按本文档的“执行顺序”逐文件生成，不要一次性让 Codex 生成整个仓库。

---

## 1. 项目目标

建设一个企业级 DevOps 平台模板，支持：

- 多 Git 源：GitHub、Gitee、未来自建 GitLab / Gitea。
- 双 CI 引擎：Jenkins 作为稳定主引擎，Tekton 作为 Kubernetes 原生引擎。
- 多语言项目：Java、Go、Python、Rust、Node.js、Vue、React。
- 多 Kubernetes 集群：dev、test、staging、prod。
- GitOps 部署：Argo CD 管理多环境同步。
- 灰度发布：Argo Rollouts 支持 Canary 和 Blue-Green。
- 安全扫描：SonarQube、Trivy、依赖漏洞扫描、Secret 扫描。
- 可观测性：Prometheus、Grafana、Loki / ELK、Jaeger。

---

## 2. 总体架构

```text
GitHub / Gitee / Self-host Git
        │
        ▼
Webhook / Pull Request / Tag Event
        │
        ├──────────────────────┐
        ▼                      ▼
Jenkins CI                 Tekton CI
传统稳定主引擎              K8s 原生云原生引擎
        │                      │
        └──────────┬───────────┘
                   ▼
        Test / Build / Scan / Package
                   │
                   ▼
          Harbor / Nexus / Reports
                   │
                   ▼
             GitOps Repository
                   │
                   ▼
                Argo CD
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
   dev cluster  test cluster  prod cluster
                   │
                   ▼
           Argo Rollouts
      Canary / Blue-Green / Rollback
                   │
                   ▼
Prometheus / Grafana / Loki / Jaeger
```

---

## 3. 仓库目录结构

Codex 需要生成如下目录结构：

```text
devops-platform/
├── README.md
├── Makefile
├── .env.example
├── docs/
│   ├── architecture.md
│   ├── release-policy.md
│   └── troubleshooting.md
├── ci-jenkins/
│   ├── Jenkinsfile
│   ├── shared-library/
│   │   └── vars/
│   │       ├── detectLanguage.groovy
│   │       ├── buildApp.groovy
│   │       ├── testApp.groovy
│   │       ├── scanImage.groovy
│   │       └── updateGitOps.groovy
│   └── examples/
│       ├── java.Jenkinsfile
│       ├── go.Jenkinsfile
│       ├── python.Jenkinsfile
│       ├── rust.Jenkinsfile
│       └── node.Jenkinsfile
├── ci-tekton/
│   ├── serviceaccount.yaml
│   ├── secrets.example.yaml
│   ├── tasks/
│   │   ├── git-clone.yaml
│   │   ├── detect-language.yaml
│   │   ├── test.yaml
│   │   ├── build.yaml
│   │   ├── image-build-kaniko.yaml
│   │   ├── trivy-scan.yaml
│   │   └── update-gitops.yaml
│   ├── pipelines/
│   │   └── multi-language-pipeline.yaml
│   ├── triggers/
│   │   ├── eventlistener.yaml
│   │   ├── triggerbinding.yaml
│   │   ├── triggertemplate.yaml
│   │   └── ingress.yaml
│   └── examples/
│       └── pipelinerun.yaml
├── gitops-repo/
│   ├── README.md
│   ├── clusters/
│   │   ├── dev/
│   │   │   ├── apps.yaml
│   │   │   └── projects.yaml
│   │   ├── test/
│   │   │   ├── apps.yaml
│   │   │   └── projects.yaml
│   │   ├── staging/
│   │   │   ├── apps.yaml
│   │   │   └── projects.yaml
│   │   └── prod/
│   │       ├── apps.yaml
│   │       └── projects.yaml
│   └── apps/
│       ├── order-service/
│       │   ├── base/
│       │   │   ├── Chart.yaml
│       │   │   ├── values.yaml
│       │   │   └── templates/
│       │   └── overlays/
│       │       ├── dev/values.yaml
│       │       ├── test/values.yaml
│       │       ├── staging/values.yaml
│       │       └── prod/values.yaml
│       ├── user-service/
│       └── payment-service/
├── helm-charts/
│   └── microservice/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-test.yaml
│       ├── values-staging.yaml
│       ├── values-prod.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           ├── serviceaccount.yaml
│           ├── configmap.yaml
│           ├── rollout-canary.yaml
│           └── rollout-bluegreen.yaml
├── argocd/
│   ├── install.md
│   ├── app-projects.yaml
│   ├── applications-dev.yaml
│   ├── applications-test.yaml
│   ├── applications-staging.yaml
│   ├── applications-prod.yaml
│   └── app-of-apps.yaml
├── rollout/
│   ├── canary.yaml
│   ├── blue-green.yaml
│   ├── analysis-template-error-rate.yaml
│   ├── analysis-template-latency.yaml
│   └── rollout-dashboard-notes.md
├── scripts/
│   ├── detect-language.sh
│   ├── build-app.sh
│   ├── test-app.sh
│   ├── docker-build.sh
│   ├── update-gitops.sh
│   ├── rollback-gitops.sh
│   └── validate-manifests.sh
├── security/
│   ├── trivy-scan.sh
│   ├── sonar-project.properties.example
│   ├── gitleaks.toml
│   └── cosign-sign.sh
├── k8s-manifests/
│   ├── namespaces.yaml
│   ├── resourcequotas.yaml
│   ├── limitranges.yaml
│   ├── rbac.yaml
│   └── networkpolicies.yaml
└── observability/
    ├── prometheus-rules.yaml
    ├── grafana-dashboard-devops.json
    ├── servicemonitor.yaml
    └── loki-notes.md
```

---

## 4. 全局变量规范

所有脚本、Pipeline、Helm values 必须统一使用以下变量。

| 变量名 | 说明 | 示例 |
|---|---|---|
| `APP_NAME` | 应用名称 | `order-service` |
| `APP_LANG` | 应用语言 | `java/go/python/rust/node` |
| `GIT_REPO_URL` | 业务代码仓库 | `https://github.com/org/order-service.git` |
| `GIT_BRANCH` | 分支 | `main` |
| `GIT_COMMIT_SHA` | commit SHA | `abc1234` |
| `IMAGE_REGISTRY` | 镜像仓库地址 | `harbor.company.com` |
| `IMAGE_PROJECT` | Harbor 项目 | `business` |
| `IMAGE_NAME` | 镜像名 | `harbor.company.com/business/order-service` |
| `IMAGE_TAG` | 镜像 tag | `abc1234` |
| `GITOPS_REPO_URL` | GitOps 仓库 | `git@git.company.com:devops/gitops-repo.git` |
| `DEPLOY_ENV` | 部署环境 | `dev/test/staging/prod` |
| `K8S_NAMESPACE` | K8s 命名空间 | `order-service-dev` |
| `ARGOCD_SERVER` | Argo CD 地址 | `argocd.company.com` |
| `SONAR_HOST_URL` | SonarQube 地址 | `https://sonar.company.com` |

### 4.1 镜像 Tag 规则

禁止使用 `latest`。

推荐规则：

```text
普通提交：${GIT_COMMIT_SHA}
Release：${VERSION}-${GIT_COMMIT_SHA}
Hotfix：hotfix-${DATE}-${GIT_COMMIT_SHA}
```

---

## 5. 分支与环境映射

| 分支 / 事件 | CI 行为 | CD 行为 | 发布策略 |
|---|---|---|---|
| `feature/*` | 单测、扫描、构建 | 不部署 | 无 |
| `develop` | 单测、扫描、构建、推镜像 | 自动部署 dev | Rolling / Canary 可选 |
| `release/*` | 完整 CI | 自动部署 test，手动部署 staging | Canary |
| `main` | 完整 CI + 审批 | 手动部署 prod | Canary / Blue-Green |
| `tag v*` | Release 构建 | 手动部署 staging/prod | Blue-Green 优先 |
| `hotfix/*` | 快速 CI + 关键扫描 | 手动部署 prod | Blue-Green / 快速回滚 |

---

## 6. Codex 执行总规则

把下面规则作为每次给 Codex 的前置约束。

```text
你是资深 DevOps / Platform Engineering 工程师。
请为一个企业级 CI/CD + GitOps 平台生成生产可用代码。
必须遵守：
1. 不要写伪代码。
2. 不要把密码、Token、私钥写入文件。
3. 所有地址、账号、Token 使用变量或 Secret 引用。
4. Kubernetes YAML 必须是合法 YAML。
5. Helm Chart 必须兼容 Helm v3。
6. Tekton 资源优先使用 tekton.dev/v1；如果使用 Triggers，资源单独放 triggers 目录。
7. Jenkins Pipeline 必须可读、可维护，失败时明确报错。
8. GitOps 更新脚本必须幂等，不能误提交无变化内容。
9. 生产环境默认不自动同步，必须人工审批。
10. 禁止使用 latest 镜像 tag。
```

---

## 7. 推荐 Codex 执行顺序

严格按以下顺序逐步生成和验证。

```text
Step 1  生成 README.md、.env.example、Makefile
Step 2  生成 scripts/*.sh 通用脚本
Step 3  生成 helm-charts/microservice Helm Chart
Step 4  生成 gitops-repo 结构和示例服务 values
Step 5  生成 argocd Application / AppProject
Step 6  生成 rollout Canary / Blue-Green / AnalysisTemplate
Step 7  生成 Jenkinsfile 和 Jenkins Shared Library
Step 8  生成 Tekton Tasks / Pipeline / Triggers
Step 9  生成 security 扫描脚本与配置
Step 10 生成 k8s-manifests 环境治理资源
Step 11 生成 observability 监控告警资源
Step 12  执行 validate-manifests.sh 验证全部 YAML / Helm 模板
```

---

# 8. 逐文件 Codex 任务包

## TASK 1：基础项目文件

### 文件：`README.md`

```text
请生成 devops-platform/README.md。

要求：
1. 介绍本项目目标：企业级 CI/CD + GitOps + 多集群 K8s + 灰度发布平台。
2. 说明目录结构。
3. 说明支持的技术栈：Java、Go、Python、Rust、Node、Vue、React。
4. 说明支持的 Git 源：GitHub、Gitee、自建 Git。
5. 说明双 CI 引擎：Jenkins 与 Tekton。
6. 说明部署方式：Argo CD GitOps。
7. 说明灰度发布：Argo Rollouts Canary / Blue-Green。
8. 提供快速开始步骤。
9. 提供环境变量说明。
10. 提供常用命令。

输出完整 Markdown 文件内容。
```

### 文件：`.env.example`

```text
请生成 .env.example。

要求包含：
APP_NAME、APP_LANG、GIT_REPO_URL、GIT_BRANCH、IMAGE_REGISTRY、IMAGE_PROJECT、IMAGE_NAME、IMAGE_TAG、GITOPS_REPO_URL、DEPLOY_ENV、K8S_NAMESPACE、ARGOCD_SERVER、SONAR_HOST_URL。
所有值使用示例值，不允许包含真实密码。
```

### 文件：`Makefile`

```text
请生成 Makefile。

要求提供以下命令：
- make lint
- make validate
- make helm-template
- make helm-lint
- make trivy-scan
- make update-gitops
- make rollback

要求：
1. 调用 scripts 目录中的脚本。
2. 每个目标都有清晰 echo 输出。
3. 失败时退出非 0。
```

---

## TASK 2：通用脚本

### 文件：`scripts/detect-language.sh`

```text
请生成 scripts/detect-language.sh。

功能：
根据项目文件自动识别语言：
- pom.xml 或 build.gradle => java
- go.mod => go
- pyproject.toml、requirements.txt、setup.py => python
- Cargo.toml => rust
- package.json => node

要求：
1. 输出识别到的语言到 stdout。
2. 识别不到时退出 1，并输出错误原因。
3. 支持在 CI 环境运行。
4. 使用 bash strict mode：set -euo pipefail。
```

### 文件：`scripts/test-app.sh`

```text
请生成 scripts/test-app.sh。

功能：
根据 APP_LANG 执行单元测试：
- java: mvn test 或 gradle test
- go: go test ./...
- python: pytest，若无 pytest 则提示安装
- rust: cargo test
- node: npm test 或 pnpm test 或 yarn test

要求：
1. APP_LANG 可通过环境变量传入；未传入时调用 detect-language.sh。
2. 单测失败必须退出 1。
3. 输出清晰日志。
4. 使用 bash strict mode。
```

### 文件：`scripts/build-app.sh`

```text
请生成 scripts/build-app.sh。

功能：
根据 APP_LANG 执行构建：
- java: mvn clean package -DskipTests 或 gradle build -x test
- go: go build -o dist/app ./...
- python: python -m build；若无 pyproject.toml，则跳过构建但打印说明
- rust: cargo build --release
- node: npm run build / pnpm build / yarn build

要求：
1. 产物统一放到 dist/ 或 target/。
2. 构建失败退出 1。
3. 使用 bash strict mode。
```

### 文件：`scripts/docker-build.sh`

```text
请生成 scripts/docker-build.sh。

功能：
构建 Docker 镜像。

要求：
1. 读取 IMAGE_NAME 和 IMAGE_TAG。
2. 禁止 IMAGE_TAG=latest。
3. 优先使用 docker buildx build；如果不可用，则使用 docker build。
4. 支持传入 Dockerfile 路径，默认 Dockerfile。
5. 构建失败退出 1。
6. 不打印敏感信息。
```

### 文件：`scripts/update-gitops.sh`

```text
请生成 scripts/update-gitops.sh。

功能：
更新 GitOps 仓库中指定服务、指定环境的 Helm values.yaml 镜像 tag。

输入环境变量：
- APP_NAME
- IMAGE_NAME
- IMAGE_TAG
- GITOPS_REPO_URL
- DEPLOY_ENV
- GIT_USER_NAME
- GIT_USER_EMAIL

要求：
1. 克隆 GitOps 仓库到临时目录。
2. 定位文件：gitops-repo/apps/${APP_NAME}/overlays/${DEPLOY_ENV}/values.yaml。
3. 使用 yq 修改 image.repository 和 image.tag。
4. 如果没有变化，不提交，正常退出 0。
5. 如果有变化，commit message 为：deploy(${APP_NAME}): update ${DEPLOY_ENV} image to ${IMAGE_TAG}。
6. push 到远端。
7. 不在日志中输出 Token 或密码。
8. 使用 bash strict mode。
```

### 文件：`scripts/rollback-gitops.sh`

```text
请生成 scripts/rollback-gitops.sh。

功能：
回滚 GitOps 仓库中的某个应用环境到上一个 Git commit。

输入环境变量：
- APP_NAME
- DEPLOY_ENV
- GITOPS_REPO_URL
- ROLLBACK_COMMIT，可选。如果为空，则回滚最近一次修改该应用环境 values.yaml 的 commit。

要求：
1. 克隆 GitOps 仓库。
2. 找到目标 values.yaml。
3. 如果提供 ROLLBACK_COMMIT，执行 git revert。
4. 如果未提供，自动定位最近一次影响目标文件的 commit 并 revert。
5. push 到远端。
6. 日志清晰。
7. 使用 bash strict mode。
```

### 文件：`scripts/validate-manifests.sh`

```text
请生成 scripts/validate-manifests.sh。

功能：
验证项目内 YAML、Helm Chart、Kubernetes manifests 是否有效。

要求：
1. 执行 helm lint helm-charts/microservice。
2. 执行 helm template 测试 dev/test/staging/prod values。
3. 如果 kubectl 可用，执行 kubectl apply --dry-run=client。
4. 如果 kubeconform 可用，执行 kubeconform。
5. 任一验证失败退出 1。
6. 使用 bash strict mode。
```

---

## TASK 3：Helm Chart

### 文件：`helm-charts/microservice/Chart.yaml`

```text
请生成 Helm v3 Chart.yaml。

要求：
1. chart 名称为 microservice。
2. type 为 application。
3. appVersion 使用 1.0.0 示例。
4. version 使用 0.1.0。
```

### 文件：`helm-charts/microservice/values.yaml`

```text
请生成 production-ready Helm values.yaml。

必须支持：
- nameOverride / fullnameOverride
- image.repository / image.tag / image.pullPolicy
- replicaCount
- serviceAccount
- podAnnotations
- podSecurityContext
- securityContext，默认非 root
- service
- ingress
- resources
- autoscaling HPA
- env
- envFrom
- livenessProbe
- readinessProbe
- nodeSelector
- tolerations
- affinity
- rollout.enabled
- rollout.strategy: canary 或 blueGreen

要求：
1. 默认镜像 tag 不允许 latest，使用占位符 0.1.0。
2. 默认 securityContext 要安全。
3. 资源限制要有默认值。
```

### 文件：`helm-charts/microservice/templates/_helpers.tpl`

```text
请生成 Helm _helpers.tpl。

要求包含：
- microservice.name
- microservice.fullname
- microservice.labels
- microservice.selectorLabels
- microservice.serviceAccountName
```

### 文件：`helm-charts/microservice/templates/deployment.yaml`

```text
请生成 deployment.yaml。

要求：
1. 当 .Values.rollout.enabled=false 时渲染 Deployment。
2. 支持 env、envFrom、resources、probes、securityContext。
3. selectorLabels 与 service 保持一致。
4. image 使用 repository:tag。
5. 不允许默认 latest。
```

### 文件：`helm-charts/microservice/templates/service.yaml`

```text
请生成 service.yaml。

要求：
1. 支持 ClusterIP/NodePort/LoadBalancer。
2. selector 与 Deployment/Rollout 一致。
3. 支持 configurable port 和 targetPort。
```

### 文件：`helm-charts/microservice/templates/ingress.yaml`

```text
请生成 ingress.yaml。

要求：
1. 由 .Values.ingress.enabled 控制。
2. 支持 ingressClassName。
3. 支持 annotations。
4. 支持 hosts、paths、tls。
5. 兼容 networking.k8s.io/v1。
```

### 文件：`helm-charts/microservice/templates/hpa.yaml`

```text
请生成 hpa.yaml。

要求：
1. 由 .Values.autoscaling.enabled 控制。
2. 支持 minReplicas、maxReplicas、targetCPUUtilizationPercentage、targetMemoryUtilizationPercentage。
3. 使用 autoscaling/v2。
```

### 文件：`helm-charts/microservice/templates/rollout-canary.yaml`

```text
请生成 Argo Rollouts Canary Helm template。

要求：
1. 当 .Values.rollout.enabled=true 且 .Values.rollout.strategy=canary 时渲染。
2. 生成 kind: Rollout。
3. 支持 canary steps：10%、30%、50%、100%。
4. 支持 analysis templates 引用。
5. pod template 与 deployment.yaml 保持一致。
```

### 文件：`helm-charts/microservice/templates/rollout-bluegreen.yaml`

```text
请生成 Argo Rollouts Blue-Green Helm template。

要求：
1. 当 .Values.rollout.enabled=true 且 .Values.rollout.strategy=blueGreen 时渲染。
2. 生成 kind: Rollout。
3. 支持 activeService、previewService。
4. 支持 autoPromotionEnabled 配置。
5. pod template 与 deployment.yaml 保持一致。
```

---

## TASK 4：GitOps 仓库

### 文件：`gitops-repo/README.md`

```text
请生成 GitOps 仓库 README。

要求说明：
1. GitOps repo 是部署唯一事实源。
2. 不允许手动 kubectl apply 生产环境。
3. 目录结构说明。
4. 如何修改应用版本。
5. 如何回滚。
6. dev/test 自动同步，staging/prod 手动审批。
```

### 文件：`gitops-repo/apps/order-service/overlays/dev/values.yaml`

```text
请生成 order-service dev 环境 values.yaml。

要求：
1. 使用 helm-charts/microservice 的 values 结构。
2. image.repository 为 harbor.company.com/business/order-service。
3. image.tag 为示例 commit SHA：dev-abc1234。
4. replicaCount 为 1。
5. rollout.enabled=false。
6. ingress host 为 order-dev.company.com。
7. resources 较小。
```

### 文件：`gitops-repo/apps/order-service/overlays/test/values.yaml`

```text
请生成 order-service test 环境 values.yaml。

要求：
1. image.tag 为 test-abc1234。
2. replicaCount 为 2。
3. rollout.enabled=true。
4. rollout.strategy=canary。
5. ingress host 为 order-test.company.com。
```

### 文件：`gitops-repo/apps/order-service/overlays/staging/values.yaml`

```text
请生成 order-service staging 环境 values.yaml。

要求：
1. image.tag 为 staging-abc1234。
2. replicaCount 为 2。
3. rollout.enabled=true。
4. rollout.strategy=canary。
5. ingress host 为 order-staging.company.com。
6. resources 接近生产。
```

### 文件：`gitops-repo/apps/order-service/overlays/prod/values.yaml`

```text
请生成 order-service prod 环境 values.yaml。

要求：
1. image.tag 为 prod-abc1234，不允许 latest。
2. replicaCount 为 4。
3. rollout.enabled=true。
4. rollout.strategy=blueGreen。
5. ingress host 为 order.company.com。
6. resources 使用生产级默认值。
7. autoscaling.enabled=true。
8. securityContext 非 root。
```

---

## TASK 5：Argo CD

### 文件：`argocd/app-projects.yaml`

```text
请生成 Argo CD AppProject YAML。

要求：
1. 定义 devops-platform 项目。
2. 允许来源仓库为 GitOps repo URL 占位符。
3. destinations 包含 dev/test/staging/prod cluster server 占位符。
4. 限制 namespace 只允许应用自己的 namespace。
5. prod 环境不允许自动 prune。
6. 包含合理的 clusterResourceWhitelist 和 namespaceResourceWhitelist。
```

### 文件：`argocd/applications-dev.yaml`

```text
请生成 dev 环境 Argo CD Application YAML。

要求：
1. 使用 GitOps repo。
2. path 指向 apps/order-service/overlays/dev 或对应 Helm values 位置。
3. destination 指向 dev cluster。
4. namespace 为 order-service-dev。
5. syncPolicy 自动同步，开启 prune 和 selfHeal。
6. 使用 Helm values 文件。
```

### 文件：`argocd/applications-test.yaml`

```text
请生成 test 环境 Argo CD Application YAML。

要求：
1. 自动同步开启。
2. namespace 为 order-service-test。
3. 支持 automated prune/selfHeal。
4. 使用 Helm values。
```

### 文件：`argocd/applications-staging.yaml`

```text
请生成 staging 环境 Argo CD Application YAML。

要求：
1. 不开启 automated sync。
2. namespace 为 order-service-staging。
3. 需要人工 sync。
4. 禁止自动 prune。
```

### 文件：`argocd/applications-prod.yaml`

```text
请生成 prod 环境 Argo CD Application YAML。

要求：
1. 不开启 automated sync。
2. namespace 为 order-service-prod。
3. 禁止自动 prune。
4. 使用 syncOptions 限制危险行为。
5. 注释说明生产同步必须走审批。
```

### 文件：`argocd/app-of-apps.yaml`

```text
请生成 Argo CD App of Apps YAML。

要求：
1. 用于统一管理 clusters/dev、clusters/test、clusters/staging、clusters/prod 下的 Application。
2. 允许 platform team 一次性接入所有环境。
3. prod 不自动同步。
```

---

## TASK 6：Argo Rollouts

### 文件：`rollout/analysis-template-error-rate.yaml`

```text
请生成 Argo Rollouts AnalysisTemplate。

功能：
基于 Prometheus 查询 HTTP 5xx 错误率。

要求：
1. metric 名称为 error-rate。
2. successCondition 为 result[0] < 0.01。
3. failureLimit 为 1。
4. interval 为 1m。
5. Prometheus 地址使用参数 prometheus-address。
6. app label 使用参数 app-name。
```

### 文件：`rollout/analysis-template-latency.yaml`

```text
请生成 Argo Rollouts AnalysisTemplate。

功能：
基于 Prometheus 查询 P95 延迟。

要求：
1. metric 名称为 p95-latency。
2. successCondition 为 result[0] < 0.5，单位秒。
3. failureLimit 为 1。
4. interval 为 1m。
5. Prometheus 地址使用参数。
```

### 文件：`rollout/canary.yaml`

```text
请生成独立可用的 Argo Rollouts Canary YAML 示例。

要求包含：
1. Rollout。
2. stable Service。
3. canary Service。
4. Canary steps：10%、30%、50%、100%。
5. 每阶段 pause。
6. analysis 引用 error-rate 和 latency AnalysisTemplate。
7. selector 和 labels 完整一致。
8. 镜像使用 harbor.company.com/business/order-service:abc1234。
```

### 文件：`rollout/blue-green.yaml`

```text
请生成独立可用的 Argo Rollouts Blue-Green YAML 示例。

要求包含：
1. Rollout。
2. active Service。
3. preview Service。
4. autoPromotionEnabled=false。
5. scaleDownDelaySeconds=600。
6. readinessProbe。
7. 支持人工确认后 promote。
```

---

## TASK 7：Jenkins CI

### 文件：`ci-jenkins/Jenkinsfile`

```text
请生成生产可用 Jenkins Declarative Pipeline。

要求：
1. 自动 checkout 当前仓库。
2. 调用 scripts/detect-language.sh 自动识别 APP_LANG。
3. 执行 scripts/test-app.sh。
4. 执行 scripts/build-app.sh。
5. 执行 SonarQube scan，如果 SONAR_HOST_URL 和 SONAR_TOKEN 存在。
6. 使用 IMAGE_TAG=git short SHA。
7. 禁止 latest tag。
8. 构建 Docker 镜像。
9. 执行 security/trivy-scan.sh。
10. 登录 Harbor 并 push 镜像，凭据从 Jenkins credentials 获取。
11. 根据分支映射 DEPLOY_ENV。
12. 只有 develop、release/*、main、tag 才更新 GitOps。
13. 调用 scripts/update-gitops.sh。
14. prod 环境要求 input 人工确认。
15. post 阶段输出成功/失败摘要。

注意：
- 不允许硬编码密码。
- 不允许使用 latest。
- 所有 shell 使用 set -euo pipefail。
```

### 文件：`ci-jenkins/shared-library/vars/detectLanguage.groovy`

```text
请生成 Jenkins Shared Library 方法 detectLanguage.groovy。

要求：
1. 调用 scripts/detect-language.sh。
2. 返回语言字符串。
3. 失败时 error 终止流水线。
```

### 文件：`ci-jenkins/shared-library/vars/buildApp.groovy`

```text
请生成 buildApp.groovy。

要求：
1. 根据语言调用 scripts/build-app.sh。
2. 输出构建日志。
3. 构建失败终止。
```

### 文件：`ci-jenkins/shared-library/vars/testApp.groovy`

```text
请生成 testApp.groovy。

要求：
1. 根据语言调用 scripts/test-app.sh。
2. 支持 JUnit 测试报告归档。
3. 失败终止。
```

### 文件：`ci-jenkins/shared-library/vars/scanImage.groovy`

```text
请生成 scanImage.groovy。

要求：
1. 调用 security/trivy-scan.sh。
2. 归档 JSON 扫描报告。
3. 高危或严重漏洞时失败。
```

### 文件：`ci-jenkins/shared-library/vars/updateGitOps.groovy`

```text
请生成 updateGitOps.groovy。

要求：
1. 调用 scripts/update-gitops.sh。
2. 支持传入 APP_NAME、IMAGE_NAME、IMAGE_TAG、DEPLOY_ENV。
3. 不输出敏感信息。
```

---

## TASK 8：Tekton CI

### 文件：`ci-tekton/serviceaccount.yaml`

```text
请生成 Tekton ServiceAccount。

要求：
1. 名称为 tekton-build-sa。
2. 引用 git credentials secret。
3. 引用 harbor docker config secret。
4. 可用于 PipelineRun。
```

### 文件：`ci-tekton/secrets.example.yaml`

```text
请生成 Tekton secrets.example.yaml。

要求：
1. 只提供示例结构，不包含真实密钥。
2. 包含 Git SSH 或 Basic Auth Secret 示例。
3. 包含 Harbor dockerconfigjson Secret 示例。
4. 注释说明生产环境应使用 External Secrets 或 Vault。
```

### 文件：`ci-tekton/tasks/detect-language.yaml`

```text
请生成 Tekton Task detect-language。

要求：
1. 输入 workspace source。
2. 根据文件识别 java/go/python/rust/node。
3. 将结果写入 task result app-lang。
4. 识别不到则失败。
```

### 文件：`ci-tekton/tasks/test.yaml`

```text
请生成 Tekton Task test。

要求：
1. 参数 app-lang。
2. workspace source。
3. 根据 app-lang 执行对应单元测试。
4. 测试失败 Task 失败。
```

### 文件：`ci-tekton/tasks/build.yaml`

```text
请生成 Tekton Task build。

要求：
1. 参数 app-lang。
2. workspace source。
3. 根据 app-lang 执行构建。
4. 产物保留在 workspace。
```

### 文件：`ci-tekton/tasks/image-build-kaniko.yaml`

```text
请生成 Tekton Task image-build-kaniko。

要求：
1. 使用 kaniko 构建镜像。
2. 参数 image-name、image-tag、dockerfile、context。
3. 禁止 image-tag 为 latest。
4. push 到 Harbor。
5. 使用 ServiceAccount 中的 docker config。
```

### 文件：`ci-tekton/tasks/trivy-scan.yaml`

```text
请生成 Tekton Task trivy-scan。

要求：
1. 参数 image-url。
2. 扫描 HIGH、CRITICAL 漏洞。
3. 输出 JSON report 到 workspace。
4. 发现 HIGH/CRITICAL 时失败。
```

### 文件：`ci-tekton/tasks/update-gitops.yaml`

```text
请生成 Tekton Task update-gitops。

要求：
1. 参数 app-name、image-name、image-tag、deploy-env、gitops-repo-url。
2. 克隆 GitOps repo。
3. 使用 yq 修改对应 values.yaml。
4. 有变化才 commit + push。
5. 使用 Git credentials。
```

### 文件：`ci-tekton/pipelines/multi-language-pipeline.yaml`

```text
请生成 Tekton Pipeline。

要求：
1. 使用 git-clone、detect-language、test、build、image-build-kaniko、trivy-scan、update-gitops。
2. 参数包含 repo-url、revision、app-name、image-name、image-tag、deploy-env、gitops-repo-url。
3. detect-language 的 result 传给 test 和 build。
4. trivy-scan 必须在 image build 后执行。
5. update-gitops 必须在 trivy-scan 成功后执行。
6. 使用 workspace 共享源码。
```

### 文件：`ci-tekton/examples/pipelinerun.yaml`

```text
请生成 PipelineRun 示例。

要求：
1. 引用 multi-language-pipeline。
2. 使用 PVC workspace。
3. 使用 tekton-build-sa。
4. 参数使用 order-service 示例。
5. deploy-env 使用 dev。
```

### 文件：`ci-tekton/triggers/eventlistener.yaml`

```text
请生成 Tekton Trigger EventListener。

要求：
1. 接收 GitHub/Gitee webhook。
2. 使用 TriggerBinding 和 TriggerTemplate。
3. 运行在 tekton-pipelines namespace。
4. 使用 tekton-build-sa。
```

### 文件：`ci-tekton/triggers/triggerbinding.yaml`

```text
请生成 TriggerBinding。

要求：
1. 从 webhook body 中提取 repo-url、revision、branch、commit。
2. 兼容 GitHub push payload。
3. 兼容 Gitee push payload，无法完全兼容时用注释说明需要按实际 payload 调整。
```

### 文件：`ci-tekton/triggers/triggertemplate.yaml`

```text
请生成 TriggerTemplate。

要求：
1. 根据 webhook 参数创建 PipelineRun。
2. image-tag 使用 commit short sha。
3. deploy-env 根据分支推导。
4. 参数完整传递给 Pipeline。
```

---

## TASK 9：安全扫描

### 文件：`security/trivy-scan.sh`

```text
请生成 security/trivy-scan.sh。

功能：
扫描 Docker 镜像漏洞和错误配置。

输入：
- IMAGE_NAME
- IMAGE_TAG
或完整 IMAGE_URL。

要求：
1. 扫描 HIGH、CRITICAL。
2. 输出 JSON 到 reports/trivy-image-report.json。
3. 输出 table 到控制台。
4. HIGH/CRITICAL 存在时退出 1。
5. 支持 Jenkins 和 Tekton。
6. 使用 bash strict mode。
```

### 文件：`security/sonar-project.properties.example`

```text
请生成 sonar-project.properties.example。

要求：
1. 支持多语言项目。
2. 配置 sonar.projectKey、sonar.projectName、sonar.sources、sonar.tests。
3. 配置 coverage report 示例：Java Jacoco、Go cover、Python coverage、Node lcov。
4. 不包含真实 Token。
```

### 文件：`security/gitleaks.toml`

```text
请生成 gitleaks 配置。

要求：
1. 检测常见 Token、AK/SK、私钥、密码。
2. 支持 allowlist。
3. 注释说明如何加入例外。
```

### 文件：`security/cosign-sign.sh`

```text
请生成 cosign-sign.sh。

功能：
对镜像进行签名。

要求：
1. 输入 IMAGE_URL。
2. 支持 keyless 或 key file 两种方式。
3. 不暴露私钥。
4. 签名失败退出 1。
```

---

## TASK 10：Kubernetes 环境治理

### 文件：`k8s-manifests/namespaces.yaml`

```text
请生成 namespaces.yaml。

要求：
1. 包含 order-service-dev、order-service-test、order-service-staging、order-service-prod。
2. 每个 namespace 带 env、app、owner label。
```

### 文件：`k8s-manifests/resourcequotas.yaml`

```text
请生成 ResourceQuota YAML。

要求：
1. dev/test/staging/prod 使用不同资源额度。
2. prod 额度最大。
3. 包含 requests.cpu、requests.memory、limits.cpu、limits.memory、pods。
```

### 文件：`k8s-manifests/limitranges.yaml`

```text
请生成 LimitRange YAML。

要求：
1. 为每个 namespace 设置默认 requests/limits。
2. 防止容器不设置资源。
```

### 文件：`k8s-manifests/rbac.yaml`

```text
请生成 RBAC YAML。

要求：
1. dev/test 环境开发可读写。
2. staging/prod 只允许平台管理员和 Argo CD ServiceAccount 写入。
3. 普通开发对 prod 只读。
4. 使用 Role、RoleBinding、ServiceAccount。
```

### 文件：`k8s-manifests/networkpolicies.yaml`

```text
请生成 NetworkPolicy YAML。

要求：
1. 默认拒绝跨 namespace 访问。
2. 允许 ingress controller 访问应用。
3. 允许 Prometheus scrape。
4. 允许应用访问必要的数据库 namespace，使用占位 label。
```

---

## TASK 11：可观测性

### 文件：`observability/prometheus-rules.yaml`

```text
请生成 PrometheusRule YAML。

要求包含告警：
1. HTTP 5xx error rate > 1%。
2. P95 latency > 500ms。
3. CPU usage > 85%。
4. Memory usage > 85%。
5. Pod restart 频繁。
6. Rollout degraded。

要求每个规则有 summary 和 description。
```

### 文件：`observability/servicemonitor.yaml`

```text
请生成 ServiceMonitor YAML。

要求：
1. 监控 app label。
2. scrape /metrics。
3. port 名称为 http-metrics。
4. interval 30s。
```

### 文件：`observability/grafana-dashboard-devops.json`

```text
请生成 Grafana Dashboard JSON。

要求展示：
1. 发布版本 image tag。
2. 请求量。
3. 错误率。
4. P95/P99 延迟。
5. CPU/Memory。
6. Pod restart。
7. Rollout status。

输出合法 JSON。
```

### 文件：`observability/loki-notes.md`

```text
请生成 Loki 日志接入说明。

要求：
1. 说明如何采集 K8s Pod 日志。
2. 说明如何按 app/env/version 查询。
3. 提供常用 LogQL 示例。
4. 说明发布异常时如何排查。
```

---

## 9. 验收标准

### 9.1 文件级验收

每个 Codex 生成的文件必须满足：

- YAML 可被解析。
- Shell 脚本包含 `set -euo pipefail`。
- 不包含真实密码、Token、AK/SK、私钥。
- 不使用 `latest` 作为默认镜像 tag。
- Kubernetes selector 和 label 保持一致。
- Helm 模板可通过 `helm lint`。
- GitOps 更新脚本无变化时不产生空 commit。

### 9.2 平台级验收

| 验收项 | 通过标准 |
|---|---|
| 多语言识别 | Java/Go/Python/Rust/Node 项目能正确识别 |
| Jenkins 构建 | 能完成 checkout/test/build/scan/push/update-gitops |
| Tekton 构建 | PipelineRun 能执行完整链路 |
| 镜像仓库 | 镜像成功推送 Harbor |
| GitOps | values.yaml tag 被正确更新 |
| Argo CD | dev/test 自动同步，prod 不自动同步 |
| Canary | 流量能按阶段推进 |
| Blue-Green | active/preview service 能切换 |
| 回滚 | git revert 后 Argo CD 能回到旧版本 |
| 安全扫描 | HIGH/CRITICAL 漏洞能阻断流水线 |
| 监控 | Prometheus 能产生发布相关告警 |

---

## 10. 常用验证命令

```bash
# Shell 语法检查
bash -n scripts/*.sh security/*.sh

# Helm 检查
helm lint helm-charts/microservice
helm template order-service helm-charts/microservice -f helm-charts/microservice/values-dev.yaml
helm template order-service helm-charts/microservice -f helm-charts/microservice/values-prod.yaml

# Kubernetes YAML dry-run
kubectl apply --dry-run=client -f k8s-manifests/
kubectl apply --dry-run=client -f argocd/
kubectl apply --dry-run=client -f rollout/

# Tekton YAML 检查
kubectl apply --dry-run=client -f ci-tekton/tasks/
kubectl apply --dry-run=client -f ci-tekton/pipelines/

# Secret 检查
gitleaks detect --source .

# Trivy 扫描示例
IMAGE_URL=harbor.company.com/business/order-service:abc1234 ./security/trivy-scan.sh
```

---

## 11. 给 Codex 的总控 Prompt

复制下面这段作为 Codex 的总控说明，然后按 TASK 逐个文件生成。

```text
你是资深 DevOps / Platform Engineering 工程师。
我要实现一个企业级 CI/CD + GitOps + 多集群 Kubernetes + 灰度发布平台。

技术栈：
- Git 源：GitHub、Gitee、未来自建 Git
- CI：Jenkins + Tekton 双引擎
- CD：Argo CD GitOps
- 运行平台：Kubernetes 多集群
- 灰度发布：Argo Rollouts Canary / Blue-Green
- 镜像仓库：Harbor
- 依赖仓库：Nexus
- 安全扫描：SonarQube、Trivy、Gitleaks、Cosign
- 可观测性：Prometheus、Grafana、Loki、Jaeger

生成代码时必须遵守：
1. 不写伪代码，输出可落地文件。
2. 不写真实密码、Token、私钥。
3. 所有凭据使用 Secret、Credentials 或环境变量。
4. 禁止 latest 镜像 tag。
5. 生产环境不自动部署，必须人工审批。
6. GitOps repo 是部署唯一事实源。
7. CI 不直接 kubectl apply 到生产。
8. 所有脚本必须有错误处理。
9. 所有 YAML 必须是合法 Kubernetes YAML。
10. Helm Chart 必须通过 helm lint。

现在请根据我指定的文件路径和要求生成对应文件。
```

---

## 12. 建议落地顺序

### 第一阶段：最小可用版本

```text
1. scripts/detect-language.sh
2. scripts/test-app.sh
3. scripts/build-app.sh
4. scripts/update-gitops.sh
5. helm-charts/microservice
6. argocd/applications-dev.yaml
7. ci-jenkins/Jenkinsfile
```

目标：完成一个 Java 或 Node 服务从提交到 dev 环境自动部署。

### 第二阶段：企业增强版

```text
1. 接入 Trivy
2. 接入 SonarQube
3. 接入 Tekton
4. 接入 Argo Rollouts Canary
5. 接入 Prometheus 指标判断
```

目标：完成质量门禁和灰度发布。

### 第三阶段：生产级版本

```text
1. prod 手动审批
2. Blue-Green 发布
3. Cosign 镜像签名
4. Gitleaks Secret 扫描
5. NetworkPolicy / RBAC / ResourceQuota
6. Grafana 发布看板
```

目标：具备生产发布、安全治理、回滚和审计能力。

---

## 13. 重要落地约束

1. 不建议一开始同时落地 Jenkins 和 Tekton，建议 Jenkins 先跑通，再补 Tekton。
2. 不建议 CI 直接操作生产 K8s，生产必须走 GitOps。
3. 不建议一开始启用复杂 Service Mesh，可先使用 Argo Rollouts + Ingress 实现基础灰度。
4. 生产环境 Argo CD 不要开启 automated sync。
5. GitOps 仓库需要开启分支保护和 MR 审批。
6. 所有敏感信息必须通过 Secret 管理，不允许写入 Git。
7. 镜像必须使用 commit SHA 或 release tag，不允许 latest。
8. 脚本必须支持重复执行，避免重复 commit 或重复创建资源导致失败。

---

## 14. 最终总结

本任务包已经补齐企业落地时必须关注的边界：多 Git 接入、双 CI 引擎、多集群 GitOps、Helm 标准化、Argo Rollouts 灰度发布、安全扫描、权限隔离、回滚和可观测性。按本文档逐文件交给 Codex 执行，可以稳定生成一个可迭代的企业级 DevOps 平台代码仓库。

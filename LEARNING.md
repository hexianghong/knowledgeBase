# AI Lessons Learned & Self-Refinement Memory

> [!IMPORTANT]
> **Instructions**: This document serves as a structured, dynamic project memory. All critical mistakes made by the AI, code style corrections enforced by developers, or new project rules **must be recorded under their respective categories** to ensure the AI does not repeat errors.
> 
> **AI Operational Safeguard**: Whenever you are corrected by a developer, you must **proactively record the lesson under the matching category header** in this file.

---

## 1. 🛡️ Security, Environment & Infrastructure
*Record lessons related to environment variables, headers, credentials, and dangerous command execution.*
- `[2026-XX-XX] [Auth]` *Example: Internal microservice calls must include the `X-Tenant-ID` Header to avoid 401 errors.*

## 2. ⚙️ Architecture, Database & API Contracts
*Record lessons related to schema design, transaction scopes, rollbacks, and API contracts.*
- `[2026-XX-XX] [Database]` *Example: Queries on the User table must include `is_deleted = 0` for soft-deletion filtering.*

## 3. 🛠️ DevOps, Shell Scripts & Operations
*Record lessons related to shell scripting security, Docker/K8s configs, and log diagnostics.*
- `[2026-08-11] [Containerd/K8s]` *Containerd 误禁用 cri 插件 (disabled_plugins=["cri"]) 会导致 Kubelet 报 rpc error: unknown service runtime.v1.RuntimeService，致使集群所有节点变为 NotReady。修复方案: 重置 containerd config default 并去除 disabled_plugins 中的 cri。*

## 4. 🎨 Code Style, Frontend & Unit Testing
*Record lessons related to strict types (no TS `any`), component decomposition, styling, and TDD unit testing.*
- `[2026-08-10] [Path Specification]` 项目中所有的文件路径及 Markdown 关联链接必须且只能使用项目级别的相对路径（例如 `./01_Inbox/03-K8S/...` 或相对当前文件的路径），严禁包含本机绝对路径（如 `/Users/...` 或 `file:///Users/...`）。

---
> [!TIP]
> **Token Context Hygiene**: When entries in this file exceed 50 items, the AI should prompt the developer to summarize recurring items into global rules and purge stale temporary entries.

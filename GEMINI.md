# [Project Name] Business Context (GEMINI.md)

## 1. Business Background & Core Functions (Context)
- **Background**: What this project does and what business goal it solves.
- **Core Flows**: Crucial business sequences and system interactions.
- **System Architecture**: Libraries, databases, and major interface details.

## 2. Project-Specific Local Rules (Local Rules)
- **文件路径规范**：项目中所有的文件路径及 Markdown 关联链接必须且只能使用项目级别的相对路径（如 `./01_Inbox/...` 或相对当前文件的相对路径），严禁在文档或代码中使用绝对路径（如 `/Users/...` 或 `file:///Users/...`）。
- **临时文件规范**：创建临时脚本、辅助工具或中间处理文件时，优先在项目根目录或项目内临时目录创建，严禁使用外部或系统级绝对路径（如 `/tmp`），用完后及时清理。
- **跨文档关联跳转规范**：编写或修改技术文档时，涉及/关联到知识库中其他已有文档技术点的内容，须建立可点击的相对路径跳转链接（正文内联自然引用 + 章末 `> [!TIP] 💡 关联技术与延伸阅读` 卡片），形成网状知识闭环并确保 0 死链。


## 3. Local Skills & Automation Scripts (Local Skills & Scripts)
- **Run/Dev**: `npm run dev` / `go run main.go`
- **Build/Test**: `npm run build` / `go test ./...`
- **AI Autonomous Repo Map**: `./automation-tools/gen-repo-map.sh .` *(AI MUST execute autonomously via run_command during planning phase)*
- **AI Autonomous Spec Archiving**: `./automation-tools/archive-specs.sh <feature-name>` *(AI MUST execute autonomously via run_command after task completion)*
- **Automation tools**: List local generators or migration tools here. The AI will prioritize executing these scripts.

## 4. Recommended Local MCP Servers (Recommended MCP Servers)
- **Database MCP**: URL or configuration (enables AI to query schema properties).
- **Git MCP**: Assisting with git operations.
- **Filesystem MCP**: Optimization for indexing larger projects.

## 5. Domain Symbols & Core Models (Domain Symbols - Repository Map)
- **Core Interfaces/Contracts**: List the most critical public interface or service definitions paths (e.g. `domain/service/order.go` or `IUserService.java`).
- **Core Models/Entities**: List crucial database entities or domain objects declarations (e.g. `model/user.go` or `User.java`).
- *Before coding, AI agents must prioritize reviewing these skeletal symbols to avoid loading deep implementation bodies or writing redundant utilities.*

## 6. AI Lessons Learned & Self-Refinement
- **Long-term Memory**: [LEARNING.md](./LEARNING.md)
- *Note: Any corrections made by developers regarding code style or mistakes must be summarized by the AI and saved to this file to prevent repeating the same errors.*

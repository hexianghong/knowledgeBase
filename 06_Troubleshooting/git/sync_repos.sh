#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: sync_repos.sh
# 功能描述: 离线/跨网络双阶段 Git 迁移工具 (针对两端网络隔离环境设计)
#   - 阶段 1 (pull): 在旧仓库网络下，全量克隆并切片检出 Commit，重置为单次 Init 提交
#   - 用户切换网络至新内网环境
#   - 阶段 2 (push): 在新仓库网络下，逐个推送至新 GitLab，推送成功一个即刻清理一个
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# 1. 账号与基础配置
# ------------------------------------------------------------------------------
OLD_GITLAB_USER="${OLD_GITLAB_USER:-admin0}"
OLD_GITLAB_PASS="${OLD_GITLAB_PASS:-3d3cb0c74f}"

NEW_GITLAB_USER="${NEW_GITLAB_USER:-root}"
NEW_GITLAB_PASS="${NEW_GITLAB_PASS:-Ilovexhyy^}"
NEW_GITLAB_BASE_URL="http://gitlab-lan.xhhos.com/wowjoy"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_FILE="${SCRIPT_DIR}/repo_list.txt"
WORK_DIR="${SCRIPT_DIR}/../../scratch/git_sync_workspace"

# ------------------------------------------------------------------------------
# 2. 辅助函数：密码特殊字符 URL 编码
# ------------------------------------------------------------------------------
url_encode() {
  local string="${1}"
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "${string}"
}

OLD_USER_ENC=$(url_encode "${OLD_GITLAB_USER}")
OLD_PASS_ENC=$(url_encode "${OLD_GITLAB_PASS}")
NEW_USER_ENC=$(url_encode "${NEW_GITLAB_USER}")
NEW_PASS_ENC=$(url_encode "${NEW_GITLAB_PASS}")

# ------------------------------------------------------------------------------
# 3. 命令行动作参数解析
# ------------------------------------------------------------------------------
ACTION="${1:-}"
TARGET_REPO="${2:-all}"

show_help() {
  echo "================================================================================"
  echo "跨网络/隔离环境 Git 迁移流程："
  echo "--------------------------------------------------------------------------------"
  echo "👉 步骤 1 (旧网络环境): 执行拉取并初始化"
  echo "   $0 pull              # 全量批量克隆所有旧仓库并重置为 Init commit"
  echo "   $0 pull vue-rcs      # 仅拉取指定服务"
  echo ""
  echo "👉 步骤 2: 手动断开旧网，切换到新仓库内网 (gitlab-lan.xhhos.com)"
  echo ""
  echo "👉 步骤 3 (新网络环境): 执行推送到新 GitLab"
  echo "   $0 push              # 批量推送已拉取的本地仓库，推送成功一个清理一个"
  echo "   $0 push vue-rcs      # 仅推送指定服务进行冒烟测试"
  echo ""
  echo "👉 查看当前本地准备状态:"
  echo "   $0 status            # 查看本地已就绪/待推送的仓库列表"
  echo "================================================================================"
  exit 0
}

if [[ -z "${ACTION}" || "${ACTION}" == "-h" || "${ACTION}" == "--help" ]]; then
  show_help
fi

if [[ ! -f "${LIST_FILE}" ]]; then
  echo "❌ 错误: 未找到迁移清单文件: ${LIST_FILE}" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}"

# ==============================================================================
# 阶段 1: PULL (在可访问旧 GitLab 的网络下执行)
# ==============================================================================
do_pull() {
  echo "================================================================================"
  echo "📥 阶段 1: 开始拉取旧仓库代码并重置为 Init 提交"
  echo "本地暂存路径: ${WORK_DIR}"
  echo "服务过滤条件: ${TARGET_REPO}"
  echo "================================================================================"

  local total=0
  local success=0
  local skipped=0
  local failed=0
  local failed_list=()

  while read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    local deploy=$(echo "${line}" | awk '{print $1}')
    local old_url=$(echo "${line}" | awk '{print $2}')
    local commit=$(echo "${line}" | awk '{print $3}')

    if [[ "${TARGET_REPO}" != "all" && "${deploy}" != "${TARGET_REPO}" ]]; then
      continue
    fi

    total=$((total + 1))
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "👉 [${total}] 处理服务: ${deploy}"

    if [[ -z "${commit}" || "${commit}" == "-" ]]; then
      echo "⏩ 跳过: [${deploy}] 无有效 Commit 哈希。"
      skipped=$((skipped + 1))
      continue
    fi

    local repo_name=$(basename "${old_url}" .git)
    local local_dir="${WORK_DIR}/${repo_name}"

    # 检查本地是否已经完成准备
    if [[ -d "${local_dir}/.git" ]]; then
      echo "ℹ️  本地目录已存在且已就绪: [${repo_name}]，跳过重复拉取。"
      success=$((success + 1))
      continue
    fi

    local old_auth_url=$(echo "${old_url}" | sed -E "s#(https?://)#\1${OLD_USER_ENC}:${OLD_PASS_ENC}@#")

    echo "   * 来源: ${old_url}"
    echo "   * 目标 Commit: ${commit}"
    echo "   * 正在克隆代码 (git clone --no-checkout)..."

    rm -rf "${local_dir}"
    local clone_err
    if ! clone_err=$(git clone --no-checkout "${old_auth_url}" "${local_dir}" 2>&1); then
      echo "❌ 克隆失败 [${deploy}]！详细错误:"
      echo "${clone_err}" | sed 's/^/      /'
      failed=$((failed + 1))
      failed_list+=("${deploy} (Clone 失败)")
      rm -rf "${local_dir}"
      continue
    fi

    cd "${local_dir}"
    echo "   * 正在检出 Commit [${commit}]..."
    local co_err
    if ! co_err=$(git checkout "${commit}" 2>&1); then
      echo "❌ 检出失败 [${deploy}]！详细错误:"
      echo "${co_err}" | sed 's/^/      /'
      failed=$((failed + 1))
      failed_list+=("${deploy} (Checkout 失败)")
      cd "${SCRIPT_DIR}"
      rm -rf "${local_dir}"
      continue
    fi

    echo "   * 正在剥离旧历史并重置为 Init commit (master)..."
    rm -rf .git
    git init -b master --quiet
    git config user.name "Administrator"
    git config user.email "admin@xhhos.com"
    git add -A
    git commit -m "Init commit from ${deploy} (${commit})" --quiet

    cd "${SCRIPT_DIR}"
    echo "✅ 就绪: [${deploy}] 已成功打包并存入本地暂存区。"
    success=$((success + 1))

  done < "${LIST_FILE}"

  echo ""
  echo "================================================================================"
  echo "📊 阶段 1 拉取完成汇总"
  echo "--------------------------------------------------------------------------------"
  echo "总计扫描: ${total} | 成功就绪: ${success} | 跳过: ${skipped} | 失败: ${failed}"
  if [[ ${failed} -gt 0 ]]; then
    echo "⚠️ 失败清单:"
    for f in "${failed_list[@]}"; do echo "  - ${f}"; done
  else
    echo "🎉 所有目标仓库已就绪！"
    echo "👉 下一步：请断开当前网络，连接至新内网 (gitlab-lan.xhhos.com)，然后运行:"
    echo "   $0 push"
  fi
  echo "================================================================================"
}

# ==============================================================================
# 阶段 2: PUSH (切换到新内网网络后执行)
# ==============================================================================
do_push() {
  echo "================================================================================"
  echo "🚀 阶段 2: 开始向新 GitLab 推送代码"
  echo "目标地址: ${NEW_GITLAB_BASE_URL}"
  echo "服务过滤: ${TARGET_REPO}"
  echo "================================================================================"

  # 1. 网络连通性快速探测
  echo -n "🔍 正在检测新 GitLab 网络连通性 (gitlab-lan.xhhos.com:80)... "
  if ! nc -z -w 3 gitlab-lan.xhhos.com 80 2>/dev/null && ! curl -s --connect-timeout 3 -I "http://gitlab-lan.xhhos.com" >/dev/null 2>&1; then
    echo "❌ 无法连通！"
    echo "⚠️ 警告: 无法连通 http://gitlab-lan.xhhos.com，请确认是否已成功切换至目标内网/VPN。"
    read -p "是否仍然尝试强制推送？(y/N): " choice
    if [[ "${choice}" != "y" && "${choice}" != "Y" ]]; then
      echo "已中止推送。"
      exit 1
    fi
  else
    echo "✅ 连通正常！"
  fi

  local total=0
  local success=0
  local skipped=0
  local failed=0
  local failed_list=()

  while read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    local deploy=$(echo "${line}" | awk '{print $1}')
    local old_url=$(echo "${line}" | awk '{print $2}')
    local commit=$(echo "${line}" | awk '{print $3}')

    if [[ "${TARGET_REPO}" != "all" && "${deploy}" != "${TARGET_REPO}" ]]; then
      continue
    fi

    local repo_name=$(basename "${old_url}" .git)
    local local_dir="${WORK_DIR}/${repo_name}"

    if [[ ! -d "${local_dir}/.git" ]]; then
      if [[ "${TARGET_REPO}" != "all" ]]; then
        echo "⚠️ 本地暂存区中未找到服务 [${deploy}]，请先在旧网下执行: $0 pull ${deploy}"
      fi
      continue
    fi

    total=$((total + 1))
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "👉 [${total}] 正在推送服务: ${deploy}"

    local new_auth_url="http://${NEW_USER_ENC}:${NEW_PASS_ENC}@gitlab-lan.xhhos.com/wowjoy/${repo_name}.git"
    local new_display_url="${NEW_GITLAB_BASE_URL}/${repo_name}.git"

    cd "${local_dir}"
    git remote remove origin 2>/dev/null || true
    git remote add origin "${new_auth_url}"

    # 关键修复：增大缓冲区至 500MB，彻底解决大代码包 HTTP 500 RPC failed 问题
    git config http.postBuffer 524288000
    git config http.maxRequestBuffer 524288000
    git config core.compression 0

    echo "   * 目标仓库: ${new_display_url}"
    echo "   * 正在推送 master 分支..."

    local push_output
    local push_status=0

    # 清除代理环境变量执行，防止内网流量被本地代理软件拦截劫持
    # 策略 1: 优先尝试带 project.create 自动建仓
    if ! push_output=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy git push -o project.create -u origin master --force 2>&1); then
      # 策略 2: 若失败（如 project.create 触发 500），尝试标准 push（应对仓库已存在的场景）
      if ! push_output=$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy git push -u origin master --force 2>&1); then
        push_status=1
      fi
    fi

    cd "${SCRIPT_DIR}"

    if [[ ${push_status} -eq 0 ]]; then
      # 推送成功立即清理本地临时代码
      rm -rf "${local_dir}"
      echo "✅ 成功: [${deploy}] 已成功推送至新仓库，本地暂存代码已清理！"
      success=$((success + 1))
    else
      echo "❌ 失败: 推送 [${deploy}] 失败！详细错误信息如下:"
      echo "${push_output}" | sed 's/^/      /'
      failed=$((failed + 1))
      failed_list+=("${deploy} (Push 失败)")
    fi

  done < "${LIST_FILE}"

  echo ""
  echo "================================================================================"
  echo "📊 阶段 2 推送完成汇总"
  echo "--------------------------------------------------------------------------------"
  echo "总计处理: ${total} | 成功推送并清理: ${success} | 失败保留: ${failed}"
  if [[ ${failed} -gt 0 ]]; then
    echo "⚠️ 失败清单 (代码仍保留在本地以便排查/重试):"
    for f in "${failed_list[@]}"; do echo "  - ${f}"; done
  else
    echo "🎉 所有服务已全部成功迁移至新 GitLab！"
    rm -rf "${WORK_DIR}"
  fi
  echo "================================================================================"
}

# ==============================================================================
# 状态查询
# ==============================================================================
do_status() {
  echo "================================================================================"
  echo "📂 本地暂存区状态 (${WORK_DIR}):"
  echo "--------------------------------------------------------------------------------"
  local count=0
  if [[ -d "${WORK_DIR}" ]]; then
    for dir in "${WORK_DIR}"/*; do
      if [[ -d "${dir}/.git" ]]; then
        count=$((count + 1))
        local rname=$(basename "${dir}")
        local cinfo=$(cd "${dir}" && git log -1 --pretty=format:"%h - %s" 2>/dev/null || echo "Init")
        echo "  [${count}] ${rname} (${cinfo})"
      fi
    done
  fi
  if [[ ${count} -eq 0 ]]; then
    echo "  (暂存区为空，尚未拉取任何仓库)"
  else
    echo "--------------------------------------------------------------------------------"
    echo "共计 ${count} 个仓库等待推送到新 GitLab。"
  fi
  echo "================================================================================"
}

# 路由执行
case "${ACTION}" in
  pull)
    do_pull
    ;;
  push)
    do_push
    ;;
  status)
    do_status
    ;;
  *)
    show_help
    ;;
esac

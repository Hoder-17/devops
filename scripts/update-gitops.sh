#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage:' \
    '  scripts/update-gitops.sh \' \
    '    --repo-url <gitops-repo-url> \' \
    '    --branch <gitops-branch> \' \
    '    --app-path <apps/service/overlays/env> \' \
    '    --image-repository <image-repository> \' \
    '    --image-tag <image-tag> \' \
    '    --commit-user <git-user-name> \' \
    '    --commit-email <git-user-email>' \
    '' \
    'Required arguments:' \
    '  --repo-url           GitOps repository URL. Supports GitHub, Gitee, and self-hosted Git.' \
    '  --branch             Target branch in the GitOps repository.' \
    '  --app-path           Path containing values.yaml inside the GitOps repository.' \
    '  --image-repository   Image repository without tag, for example harbor.company.com/business/order-service.' \
    '  --image-tag          Image tag. The value "latest" is not allowed.' \
    '  --commit-user        Git commit user name.' \
    '  --commit-email       Git commit user email.' \
    '' \
    'Environment defaults (CLI options take precedence):' \
    '  GITOPS_REPO_URL, GITOPS_BRANCH, GITOPS_APP_PATH, IMAGE_REPOSITORY,' \
    '  IMAGE_TAG, GIT_USER_NAME, GIT_USER_EMAIL, APP_NAME, APP_ENV.' \
    '  When GITOPS_APP_PATH is unset, APP_NAME and APP_ENV derive' \
    '  apps/<APP_NAME>/overlays/<APP_ENV>.' \
    '' \
    'Migration aliases:' \
    '  DEPLOY_ENV is accepted for APP_ENV and IMAGE_NAME for IMAGE_REPOSITORY.' \
    '  Conflicting standard and alias values are rejected.' \
    '' \
    'The script updates <app-path>/values.yaml:' \
    '  image.repository' \
    '  image.tag' \
    '' \
    'No credentials are printed. Pass authentication through Git credential helpers,' \
    'SSH agent, CI credentials, Kubernetes Secret, External Secrets, or Vault.'
}

log() {
  printf '[update-gitops] %s\n' "$*"
}

die() {
  printf '[update-gitops] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

mask_repo_url() {
  local url="$1"

  case "$url" in
    git@*:*)
      printf '%s\n' "$url" | sed -E 's#^(git@[^:]+:).*$#\1***#'
      ;;
    ssh://*@*/*)
      printf '%s\n' "$url" | sed -E 's#^(ssh://)[^@]+@([^/]+)/.*$#\1***@\2/***#'
      ;;
    http://*|https://*)
      printf '%s\n' "$url" | sed -E 's#^(https?://)([^/@]+@)?([^/]+)/.*$#\1\3/***#'
      ;;
    *)
      printf '***\n'
      ;;
  esac
}

is_blank() {
  [[ -z "${1//[[:space:]]/}" ]]
}

validate_alias() {
  local standard_name="$1"
  local standard_value="$2"
  local alias_name="$3"
  local alias_value="$4"

  if ! is_blank "$standard_value" && ! is_blank "$alias_value" && [[ "$standard_value" != "$alias_value" ]]; then
    die "conflicting values for ${standard_name} and compatibility alias ${alias_name}"
  fi
}

resolve_environment_defaults() {
  local standard_app_env="${APP_ENV:-}"
  local legacy_deploy_env="${DEPLOY_ENV:-}"
  local standard_image_repository="${IMAGE_REPOSITORY:-}"
  local legacy_image_name="${IMAGE_NAME:-}"

  validate_alias "APP_ENV" "$standard_app_env" "DEPLOY_ENV" "$legacy_deploy_env"
  validate_alias "IMAGE_REPOSITORY" "$standard_image_repository" "IMAGE_NAME" "$legacy_image_name"

  app_name="${APP_NAME:-}"
  app_env="$standard_app_env"
  [[ -n "$app_env" ]] || app_env="$legacy_deploy_env"
  [[ -n "$standard_image_repository" ]] || standard_image_repository="$legacy_image_name"

  [[ -n "$repo_url" ]] || repo_url="${GITOPS_REPO_URL:-}"
  [[ -n "$branch" ]] || branch="${GITOPS_BRANCH:-}"
  [[ -n "$app_path" ]] || app_path="${GITOPS_APP_PATH:-}"
  [[ -n "$image_repository" ]] || image_repository="$standard_image_repository"
  [[ -n "$image_tag" ]] || image_tag="${IMAGE_TAG:-}"
  [[ -n "$commit_user" ]] || commit_user="${GIT_USER_NAME:-}"
  [[ -n "$commit_email" ]] || commit_email="${GIT_USER_EMAIL:-}"

  if is_blank "$app_path" && ! is_blank "$app_name" && ! is_blank "$app_env"; then
    app_path="apps/${app_name}/overlays/${app_env}"
  fi
}

parse_args() {
  repo_url=""
  branch=""
  app_path=""
  image_repository=""
  image_tag=""
  commit_user=""
  commit_email=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-url)
        [[ $# -ge 2 ]] || die "--repo-url requires a value"
        repo_url="$2"
        shift 2
        ;;
      --branch)
        [[ $# -ge 2 ]] || die "--branch requires a value"
        branch="$2"
        shift 2
        ;;
      --app-path)
        [[ $# -ge 2 ]] || die "--app-path requires a value"
        app_path="$2"
        shift 2
        ;;
      --image-repository)
        [[ $# -ge 2 ]] || die "--image-repository requires a value"
        image_repository="$2"
        shift 2
        ;;
      --image-tag)
        [[ $# -ge 2 ]] || die "--image-tag requires a value"
        image_tag="$2"
        shift 2
        ;;
      --commit-user)
        [[ $# -ge 2 ]] || die "--commit-user requires a value"
        commit_user="$2"
        shift 2
        ;;
      --commit-email)
        [[ $# -ge 2 ]] || die "--commit-email requires a value"
        commit_email="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

validate_inputs() {
  is_blank "$repo_url" && die "--repo-url is required"
  is_blank "$branch" && die "--branch is required"
  is_blank "$app_path" && die "--app-path is required"
  is_blank "$image_repository" && die "--image-repository is required"
  is_blank "$image_tag" && die "--image-tag is required"
  is_blank "$commit_user" && die "--commit-user is required"
  is_blank "$commit_email" && die "--commit-email is required"

  if [[ "$image_tag" == "latest" ]]; then
    die "IMAGE_TAG=latest is not allowed"
  fi
  if [[ "$app_path" = /* ]]; then
    die "--app-path must be relative to the GitOps repository root"
  fi
  if [[ "$app_path" == *".."* ]]; then
    die "--app-path must not contain '..'"
  fi
}

yaml_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

update_values_file() {
  local values_file="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  awk -v repo="$(yaml_quote "$image_repository")" -v tag="$(yaml_quote "$image_tag")" '
    function indent_of(line) {
      match(line, /^[ ]*/)
      return RLENGTH
    }

    function emit_missing() {
      if (in_image) {
        if (!saw_repository) {
          print child_indent "repository: " repo
        }
        if (!saw_tag) {
          print child_indent "tag: " tag
        }
      }
    }

    BEGIN {
      in_image = 0
      saw_image = 0
      saw_repository = 0
      saw_tag = 0
      image_indent = -1
      child_indent = "  "
    }

    /^[ ]*image:[ ]*$/ {
      emit_missing()
      in_image = 1
      saw_image = 1
      saw_repository = 0
      saw_tag = 0
      image_indent = indent_of($0)
      child_indent = substr($0, 1, image_indent) "  "
      print
      next
    }

    {
      current_indent = indent_of($0)
      if (in_image && $0 !~ /^[ ]*$/ && current_indent <= image_indent && $0 !~ /^[ ]*#/) {
        emit_missing()
        in_image = 0
      }

      if (in_image && $0 ~ /^[ ]*repository:[ ]*/) {
        print child_indent "repository: " repo
        saw_repository = 1
        next
      }

      if (in_image && $0 ~ /^[ ]*tag:[ ]*/) {
        print child_indent "tag: " tag
        saw_tag = 1
        next
      }

      print
    }

    END {
      emit_missing()
      if (!saw_image) {
        print ""
        print "image:"
        print "  repository: " repo
        print "  tag: " tag
      }
    }
  ' "$values_file" > "$tmp_file"

  mv "$tmp_file" "$values_file"
}

parse_args "$@"
resolve_environment_defaults
validate_inputs
require_command git
require_command mktemp
require_command awk
require_command sed
require_command mv
require_command rm

tmp_dir="$(mktemp -d)"
repo_dir="$tmp_dir/repo"
masked_repo_url="$(mask_repo_url "$repo_url")"

cleanup() {
  if [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

export GIT_TERMINAL_PROMPT=0

log "cloning GitOps repository: $masked_repo_url"
if ! git clone --quiet --branch "$branch" --single-branch "$repo_url" "$repo_dir" 2>"$tmp_dir/git-clone.err"; then
  die "failed to clone GitOps repository; verify repo URL, branch, and credentials"
fi

cd "$repo_dir"

log "checking out branch: $branch"
if ! git checkout --quiet "$branch"; then
  die "failed to checkout target branch"
fi

values_file="$repo_dir/$app_path/values.yaml"
[[ -f "$values_file" ]] || die "values file not found at app path: $app_path/values.yaml"

log "updating image values in: $app_path/values.yaml"
update_values_file "$values_file"

if git diff --quiet -- "$values_file"; then
  log "image values are already up to date; nothing to commit"
  exit 0
fi

git config user.name "$commit_user"
git config user.email "$commit_email"

git add "$values_file"

if ! is_blank "${app_name:-}" && ! is_blank "${app_env:-}"; then
  commit_message="deploy(${app_name}): update ${app_env} image to ${image_tag}"
else
  commit_message="deploy(${app_path}): update image to ${image_tag}"
fi
log "creating GitOps commit for image tag: $image_tag"
git commit --quiet -m "$commit_message"

log "pushing GitOps update to branch: $branch"
if ! git push --quiet origin "$branch" 2>"$tmp_dir/git-push.err"; then
  die "failed to push GitOps update; verify branch permissions and credentials"
fi

log "GitOps update completed"

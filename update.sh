#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  echo "Erro: este diretório não está dentro de um repositório Git."
  exit 1
fi

cd "${repo_root}"

branch="$(git branch --show-current)"
if [[ -z "${branch}" ]]; then
  echo "Erro: não foi possível identificar a branch atual."
  exit 1
fi

commit_message="${*:-Atualização $(date '+%Y-%m-%d %H:%M:%S')}"

echo "Repositório: ${repo_root}"
echo "Branch: ${branch}"
echo
echo "Status antes do add:"
git status --short || true
echo

git add -A

if git diff --cached --quiet; then
  echo "Nenhuma alteração para commit."
  exit 0
fi

echo "Alterações que serão commitadas:"
git diff --cached --name-status
echo

echo "Commit message: ${commit_message}"
git commit -m "${commit_message}"

echo
echo "Enviando para origin/${branch}..."
git push origin "${branch}"

echo
echo "Concluído."

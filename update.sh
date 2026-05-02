#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

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
max_file_size_mb="${MAX_FILE_SIZE_MB:-95}"
max_file_size_bytes=$((max_file_size_mb * 1024 * 1024))

# Arquivos que nunca devem entrar no commit por este script.
excluded_paths=(
  "Data/discentes_2024_campos_analise_area45.csv"
)

tmp_untracked="$(mktemp)"
tmp_staged="$(mktemp)"
trap 'rm -f "${tmp_untracked}" "${tmp_staged}"' EXIT

echo "Repositório: ${repo_root}"
echo "Branch: ${branch}"
echo
echo "Status antes do add:"
git status --short || true
echo

# 1) Stage de alterações em arquivos já rastreados.
git add -u

# 2) Stage de arquivos novos, ignorando arquivos grandes e caminhos excluídos.
added_new=0
skipped_large=()
skipped_excluded=()
unstaged_large=()

git ls-files --others --exclude-standard -z > "${tmp_untracked}"
while IFS= read -r -d '' file_path; do
  skip=false
  for excluded in "${excluded_paths[@]}"; do
    if [[ "${file_path}" == "${excluded}" ]]; then
      skipped_excluded+=("${file_path}")
      skip=true
      break
    fi
  done
  if [[ "${skip}" == true ]]; then
    continue
  fi

  if [[ ! -f "${file_path}" ]]; then
    continue
  fi

  file_size_bytes="$(wc -c < "${file_path}")"
  if (( file_size_bytes > max_file_size_bytes )); then
    skipped_large+=("${file_path} (${file_size_bytes} bytes)")
    continue
  fi

  git add -- "${file_path}"
  added_new=$((added_new + 1))
done < "${tmp_untracked}"

# 3) Garante que caminhos excluídos não fiquem staged por acidente.
for excluded in "${excluded_paths[@]}"; do
  git restore --staged -- "${excluded}" 2>/dev/null || true
done

# 4) Segurança extra: remove do stage qualquer arquivo acima do limite.
git diff --cached --name-only > "${tmp_staged}"
while IFS= read -r staged_file; do
  [[ -z "${staged_file}" ]] && continue
  [[ ! -f "${staged_file}" ]] && continue
  staged_size_bytes="$(wc -c < "${staged_file}")"
  if (( staged_size_bytes > max_file_size_bytes )); then
    git restore --staged -- "${staged_file}" 2>/dev/null || true
    unstaged_large+=("${staged_file} (${staged_size_bytes} bytes)")
  fi
done < "${tmp_staged}"

if (( added_new > 0 )); then
  echo "Arquivos novos adicionados ao stage: ${added_new}"
  echo
fi

if (( ${#skipped_excluded[@]} > 0 )); then
  echo "Arquivos pulados por exclusão explícita:"
  printf '  - %s\n' "${skipped_excluded[@]}"
  echo
fi

if (( ${#skipped_large[@]} > 0 )); then
  echo "Arquivos novos pulados por tamanho (> ${max_file_size_mb}MB):"
  printf '  - %s\n' "${skipped_large[@]}"
  echo
fi

if (( ${#unstaged_large[@]} > 0 )); then
  echo "Arquivos removidos do stage por tamanho (> ${max_file_size_mb}MB):"
  printf '  - %s\n' "${unstaged_large[@]}"
  echo
fi

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

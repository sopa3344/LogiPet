#!/bin/bash
set -euo pipefail

REPOSITORY="sopa3344/LogiPet"
APP_NAME="LogiPet-macOS.app"
INSTALL_DIR="$HOME/Applications"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME"

print_usage() {
  cat <<'EOF'
LogiPet macOS 간편 설치

사용법:
  /bin/bash install-macos.sh

환경 변수:
  LOGIPET_ASSUME_YES=1  확인 질문 없이 설치합니다.
  LOGIPET_SKIP_LAUNCH=1 설치 후 앱을 실행하지 않습니다.
EOF
}

fail() {
  printf '\n[LogiPet] %s\n' "$1" >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  print_usage
  exit 0
fi

[[ $# -eq 0 ]] || fail "지원하지 않는 옵션입니다. --help를 확인해 주세요."
[[ "$(uname -s)" == "Darwin" ]] || fail "이 설치 스크립트는 macOS에서만 실행할 수 있습니다."

for command_name in curl ditto xattr codesign open sw_vers; do
  command -v "$command_name" >/dev/null 2>&1 || fail "필요한 명령을 찾을 수 없습니다: $command_name"
done

macos_version="$(sw_vers -productVersion)"
macos_major="${macos_version%%.*}"
[[ "$macos_major" =~ ^[0-9]+$ ]] || fail "macOS 버전을 확인할 수 없습니다: $macos_version"
(( macos_major >= 13 )) || fail "LogiPet은 macOS 13 이상에서 실행됩니다. 현재 버전: $macos_version"

machine="$(uname -m)"
translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || printf '0')"

if [[ "$machine" == "arm64" || "$translated" == "1" ]]; then
  asset="LogiPet-macOS-Apple-Silicon.zip"
  chip_label="Apple Silicon"
elif [[ "$machine" == "x86_64" ]]; then
  asset="LogiPet-macOS-Intel.zip"
  chip_label="Intel"
else
  fail "지원하지 않는 Mac 아키텍처입니다: $machine"
fi

download_url="https://github.com/$REPOSITORY/releases/latest/download/$asset"

printf '\nLogiPet macOS 간편 설치\n'
printf '  Mac 종류: %s\n' "$chip_label"
printf '  설치 위치: %s\n' "$INSTALL_PATH"
printf '  다운로드: %s\n' "$download_url"
printf '\n이 설치본은 Developer ID 공증을 받지 않은 공개 소스 데모입니다.\n'
printf '스크립트는 위 GitHub Release에서 앱을 받고 해당 앱의 격리 속성만 제거합니다.\n'

if [[ "${LOGIPET_ASSUME_YES:-0}" != "1" ]]; then
  [[ -r /dev/tty ]] || fail "확인 입력을 받을 수 없습니다. LOGIPET_ASSUME_YES=1을 지정해 주세요."
  printf '\n계속 설치할까요? [y/N] '
  read -r reply </dev/tty
  case "$reply" in
    y|Y|yes|YES|Yes) ;;
    *) printf '설치를 취소했습니다.\n'; exit 0 ;;
  esac
fi

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/logipet-install.XXXXXX")"
cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT

archive="$temp_dir/$asset"
extracted_dir="$temp_dir/extracted"
mkdir -p "$extracted_dir"

printf '\n[1/4] 최신 LogiPet 다운로드 중...\n'
curl --fail --location --retry 3 --progress-bar "$download_url" --output "$archive"

printf '[2/4] 배포 파일 확인 중...\n'
ditto -x -k "$archive" "$extracted_dir"
source_app="$extracted_dir/$APP_NAME"
[[ -d "$source_app" ]] || fail "ZIP 안에서 $APP_NAME을 찾지 못했습니다."
[[ -x "$source_app/Contents/MacOS/LogiPetMac" ]] || fail "앱 실행 파일 또는 실행 권한이 올바르지 않습니다."
codesign --verify --deep --strict "$source_app" >/dev/null 2>&1 || fail "다운로드한 앱의 코드 서명이 손상되었습니다."

printf '[3/4] 사용자 응용 프로그램 폴더에 설치 중...\n'
mkdir -p "$INSTALL_DIR"
pkill -x LogiPetMac >/dev/null 2>&1 || true

previous_app=""
if [[ -e "$INSTALL_PATH" ]]; then
  previous_app="$temp_dir/previous-$APP_NAME"
  mv "$INSTALL_PATH" "$previous_app"
fi

if ! ditto "$source_app" "$INSTALL_PATH"; then
  [[ ! -e "$INSTALL_PATH" ]] || mv "$INSTALL_PATH" "$temp_dir/failed-$APP_NAME"
  [[ -z "$previous_app" ]] || mv "$previous_app" "$INSTALL_PATH"
  fail "앱을 설치하지 못했습니다. 기존 설치본은 복원했습니다."
fi

chmod +x "$INSTALL_PATH/Contents/MacOS/LogiPetMac"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true
codesign --verify --deep --strict "$INSTALL_PATH" >/dev/null 2>&1 || {
  mv "$INSTALL_PATH" "$temp_dir/failed-$APP_NAME"
  [[ -z "$previous_app" ]] || mv "$previous_app" "$INSTALL_PATH"
  fail "설치 후 앱 검증에 실패했습니다. 기존 설치본은 복원했습니다."
}

if [[ "${LOGIPET_SKIP_LAUNCH:-0}" == "1" ]]; then
  printf '[4/4] 설치 검증 완료. 앱 실행은 생략했습니다.\n'
else
  printf '[4/4] LogiPet 실행 중...\n'
  open "$INSTALL_PATH"
fi

printf '\n설치가 완료되었습니다.\n'
printf 'Finder에서 이동 → 홈 → Applications → %s에서 다시 실행할 수 있습니다.\n' "$APP_NAME"
printf '처음 사용할 때 Bluetooth와 손쉬운 사용 권한을 허용해 주세요.\n'

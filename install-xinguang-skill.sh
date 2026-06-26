#!/usr/bin/env bash
set -Eeuo pipefail

XINGUANG_SKILL_INSTALLER_VERSION="2026-06-26.2"
XINGUANG_SKILL_VERSION="3.0.1"
SKILL_NAME="wainfort-ai-lighting-run"
SKILL_COMPANY="深圳市馨光智能物联有限公司"

INSTALL_ACTION="${INSTALL_ACTION:-full}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/wainfort-light}"
LOG_FILE="${LOG_FILE:-/tmp/xinguang-skill-install-current.log}"
STATE_FILE="${STATE_FILE:-/tmp/xinguang-skill-install.state}"
PID_FILE="${PID_FILE:-/tmp/xinguang-skill-install.pid}"
SERVER_URL="${SERVER_URL:-http://appagent.wainfort.com/download/wainfort-server}"
WAINFORT_SERVER_SHA256="${WAINFORT_SERVER_SHA256:-49bbd86dd064baf09d1914003638969a7a937a36a5a447ea6a28bde527e3df7c}"
WAINFORT_API_PORT="${WAINFORT_API_PORT:-1888}"
WAINFORT_MILOCO_URL="${WAINFORT_MILOCO_URL:-http://127.0.0.1:1810}"
ROTATE_WAINFORT_TOKEN="${ROTATE_WAINFORT_TOKEN:-0}"
XINGUANG_TARGET_HOME="${XINGUANG_TARGET_HOME:-}"
XINGUANG_TARGET_ROOM="${XINGUANG_TARGET_ROOM:-}"
XINGUANG_TARGET_DEVICE_NAME="${XINGUANG_TARGET_DEVICE_NAME:-}"
XINGUANG_TARGET_PRODUCT="${XINGUANG_TARGET_PRODUCT:-馨光RGBCW幻彩灯带}"

SKILL_URLS="${SKILL_URLS:-https://nijez.github.io/xingguang-ai-lighting-guide/skills/wainfort-ai-lighting-run/SKILL.md https://nijez.github.io/xingguang-ai-lighting-guide/wainfort-ai-lighting-run-skill.txt https://raw.githubusercontent.com/nijez/xingguang-ai-lighting-guide/main/skills/wainfort-ai-lighting-run/SKILL.md https://cdn.jsdelivr.net/gh/nijez/xingguang-ai-lighting-guide@main/skills/wainfort-ai-lighting-run/SKILL.md}"

ENV_FILE="$INSTALL_DIR/.env"
SERVER_BIN="$INSTALL_DIR/wainfort-server"
SERVER_PID_FILE="$INSTALL_DIR/wainfort-server.pid"
API_LOG="$INSTALL_DIR/api.log"
PUBLIC_SKILL_DIR="$INSTALL_DIR/downloads/$SKILL_NAME"
LOCAL_SKILL_DIR="${LOCAL_SKILL_DIR:-/tmp/xinguang-skill/$SKILL_NAME}"
LOCAL_SKILL_FILE="$LOCAL_SKILL_DIR/SKILL.md"
DEVICE_CACHE="$INSTALL_DIR/devices-last.json"
HOME_LIST_CACHE="$INSTALL_DIR/homes-last.json"
CURRENT_HOME_CACHE="$INSTALL_DIR/current-home-last.txt"
HOME_SWITCH_RESULT="$INSTALL_DIR/home-switch-result.txt"
TARGET_HOME_FILE="$INSTALL_DIR/target-home.env"
TARGET_DEVICE_FILE="$INSTALL_DIR/target-device.json"
DEVICE_REPORT="$INSTALL_DIR/device-report.txt"

mkdir -p "$(dirname "$LOG_FILE")" "$INSTALL_DIR"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '[%s] %s\n' "$(date '+%F %T %Z')" "$*" >&2
}

state_mark() {
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s %s\n' "$(date '+%F %T %Z')" "$1" >>"$STATE_FILE"
  log "STATE: $1"
}

die() {
  state_mark "ERROR: $*"
  printf '\n馨光 Skill 安装未完成\n原因：%s\n日志文件：%s\n状态文件：%s\n' "$*" "$LOG_FILE" "$STATE_FILE" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

version() {
  printf '%s\n' "$XINGUANG_SKILL_INSTALLER_VERSION"
}

status_file_has() {
  [[ -f "$STATE_FILE" ]] && grep -q "$1" "$STATE_FILE"
}

load_env_if_present() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
  fi
}

generate_token() {
  local suffix
  if have openssl; then
    suffix="$(openssl rand -hex 18)"
  elif [[ -r /proc/sys/kernel/random/uuid ]]; then
    suffix="$(tr -d '-' </proc/sys/kernel/random/uuid)"
  elif have sha256sum; then
    suffix="$(printf '%s:%s:%s' "$(date +%s%N)" "$RANDOM" "$(hostname 2>/dev/null || true)" | sha256sum | awk '{print $1}')"
  else
    suffix="$(printf '%s%s%s' "$(date +%s)" "$RANDOM" "$RANDOM")"
  fi
  printf 'wainfort-ai-2026-%s\n' "$suffix"
}

ensure_env_file() {
  mkdir -p "$INSTALL_DIR"
  chmod 700 "$INSTALL_DIR" 2>/dev/null || true

  local token="${WAINFORT_API_TOKEN:-}"
  if [[ "$ROTATE_WAINFORT_TOKEN" != 1 && -f "$ENV_FILE" ]]; then
    token="$(grep -E '^WAINFORT_API_TOKEN=' "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
  fi
  if [[ -z "$token" ]]; then
    token="$(generate_token)"
  fi

  umask 077
  cat >"$ENV_FILE" <<EOF
WAINFORT_API_TOKEN=$token
WAINFORT_MILOCO_URL=$WAINFORT_MILOCO_URL
WAINFORT_MILOCO_TOKEN=${WAINFORT_MILOCO_TOKEN:-}
WAINFORT_API_PORT=$WAINFORT_API_PORT
EOF
  chmod 600 "$ENV_FILE" 2>/dev/null || true
  export WAINFORT_API_TOKEN="$token"
  export WAINFORT_MILOCO_URL
  export WAINFORT_MILOCO_TOKEN="${WAINFORT_MILOCO_TOKEN:-}"
  export WAINFORT_API_PORT
  state_mark TOKEN_CONFIGURED
}

download_file() {
  local target="$1"
  shift
  local url
  rm -f "$target"
  for url in "$@"; do
    log "尝试下载：$url"
    if curl -fL --retry 2 --connect-timeout 15 --max-time 900 "$url" -o "$target"; then
      [[ -s "$target" ]] && return 0
    fi
    log "当前下载源不可用，继续尝试下一个源"
  done
  return 1
}

download_skill() {
  mkdir -p "$PUBLIC_SKILL_DIR"
  # shellcheck disable=SC2206
  local urls=($SKILL_URLS)
  download_file "$PUBLIC_SKILL_DIR/SKILL.md" "${urls[@]}" || die "馨光 Skill 文件下载失败"

  grep -q "^name: $SKILL_NAME$" "$PUBLIC_SKILL_DIR/SKILL.md" || die "馨光 Skill 名称校验失败"
  grep -q "\"version\":\"$XINGUANG_SKILL_VERSION\"" "$PUBLIC_SKILL_DIR/SKILL.md" || die "馨光 Skill 版本校验失败"
  grep -q "$SKILL_COMPANY" "$PUBLIC_SKILL_DIR/SKILL.md" || die "馨光 Skill 公司信息校验失败"
  state_mark SKILL_DOWNLOAD_DONE
}

prepare_local_skill() {
  mkdir -p "$LOCAL_SKILL_DIR"
  cp "$PUBLIC_SKILL_DIR/SKILL.md" "$LOCAL_SKILL_FILE"
  perl -0pi -e "s/wainfort-ai-2026-你的本地Token/$WAINFORT_API_TOKEN/g" "$LOCAL_SKILL_FILE"
  chmod 700 "$LOCAL_SKILL_DIR" 2>/dev/null || true
  chmod 600 "$LOCAL_SKILL_FILE" 2>/dev/null || true
  state_mark SKILL_LOCAL_CONFIG_READY
}

openclaw_has_skills_command() {
  have openclaw || return 1
  openclaw skills --help >/dev/null 2>&1
}

install_skill_with_openclaw_command() {
  openclaw_has_skills_command || return 1

  if timeout 180s openclaw skills install "$LOCAL_SKILL_DIR" --as "$SKILL_NAME" --global; then
    return 0
  fi
  if timeout 180s openclaw skills install "$LOCAL_SKILL_DIR" --as "$SKILL_NAME"; then
    return 0
  fi
  return 1
}

reload_openclaw_best_effort() {
  have openclaw || return 0
  timeout 60s openclaw skills reload >/dev/null 2>&1 || true
  timeout 90s openclaw gateway restart >/dev/null 2>&1 || true
}

skill_install_verified() {
  have openclaw || return 1
  if timeout 60s openclaw skills info "$SKILL_NAME" >/dev/null 2>&1; then
    return 0
  fi
  timeout 60s openclaw skills list 2>/dev/null | grep -qi 'wainfort'
}

install_skill() {
  prepare_local_skill
  if install_skill_with_openclaw_command; then
    reload_openclaw_best_effort
    if skill_install_verified; then
      state_mark SKILL_INSTALL_DONE
      state_mark SKILL_INSTALL_VERIFIED
      return 0
    fi
    die "馨光 Skill 安装失败，请联系技术人员处理。"
  fi
  die "馨光 Skill 安装失败，请联系技术人员处理。"
}

verify_server_checksum() {
  if [[ -z "$WAINFORT_SERVER_SHA256" ]]; then
    log "WARNING: 当前未配置 wainfort-server 校验值，正式发布前建议补充。"
    state_mark SERVER_SHA256_NOT_CONFIGURED
    return 0
  fi

  if have sha256sum; then
    printf '%s  %s\n' "$WAINFORT_SERVER_SHA256" "$SERVER_BIN" | sha256sum -c - >/dev/null ||
      die "wainfort-server SHA256 校验失败"
    state_mark SERVER_SHA256_OK
    return 0
  fi
  if have shasum; then
    printf '%s  %s\n' "$WAINFORT_SERVER_SHA256" "$SERVER_BIN" | shasum -a 256 -c - >/dev/null ||
      die "wainfort-server SHA256 校验失败"
    state_mark SERVER_SHA256_OK
    return 0
  fi
  die "无法校验 wainfort-server 文件，请联系技术人员处理。"
}

download_server() {
  download_file "$SERVER_BIN" "$SERVER_URL" || die "wainfort-server 下载失败"
  verify_server_checksum
  chmod +x "$SERVER_BIN"
  state_mark SERVER_DOWNLOAD_DONE
}

server_process_running() {
  if [[ -f "$SERVER_PID_FILE" ]]; then
    local pid
    pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
    [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1 && return 0
  fi
  pgrep -f "$SERVER_BIN" >/dev/null 2>&1
}

server_status_ok() {
  curl -fsS --max-time 5 "http://127.0.0.1:$WAINFORT_API_PORT/api/status" >/dev/null 2>&1 && return 0

  local token="${WAINFORT_API_TOKEN:-}"
  [[ -n "$token" ]] && curl -fsS --max-time 5 \
    -H "Authorization: Bearer $token" \
    "http://127.0.0.1:$WAINFORT_API_PORT/api/status" >/dev/null 2>&1
}

start_server() {
  load_env_if_present
  if server_status_ok || server_process_running; then
    state_mark SERVER_ALREADY_RUNNING
    return 0
  fi

  : >"$API_LOG"
  nohup env \
    WAINFORT_API_TOKEN="$WAINFORT_API_TOKEN" \
    WAINFORT_MILOCO_URL="$WAINFORT_MILOCO_URL" \
    WAINFORT_MILOCO_TOKEN="${WAINFORT_MILOCO_TOKEN:-}" \
    WAINFORT_API_PORT="$WAINFORT_API_PORT" \
    "$SERVER_BIN" >>"$API_LOG" 2>&1 &
  printf '%s\n' "$!" >"$SERVER_PID_FILE"
  state_mark SERVER_STARTED

  local i
  for i in $(seq 1 30); do
    if server_status_ok; then
      state_mark SERVER_STATUS_OK
      return 0
    fi
    sleep 2
  done

  if server_process_running; then
    state_mark SERVER_PROCESS_RUNNING_STATUS_PENDING
    return 0
  fi
  die "wainfort-server 未能启动"
}

query_home_list() {
  load_env_if_present
  rm -f "$HOME_LIST_CACHE"
  local tmp="$HOME_LIST_CACHE.tmp"

  if have miloco-cli; then
    local args
    for args in \
      "scope home list --json" \
      "scope homes list --json" \
      "home list --json" \
      "homes list --json" \
      "family list --json" \
      "families list --json" \
      "account homes --json" \
      "account families --json"
    do
      if timeout 25s miloco-cli $args >"$tmp" 2>/dev/null && [[ -s "$tmp" ]] && python3 -m json.tool "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$HOME_LIST_CACHE"
        return 0
      fi
    done
  fi

  local endpoint
  for endpoint in homes families home-list family-list; do
    if curl -fsS --max-time 12 \
      -H "Authorization: Bearer ${WAINFORT_API_TOKEN:-}" \
      "http://127.0.0.1:$WAINFORT_API_PORT/api/$endpoint" \
      -o "$tmp" && [[ -s "$tmp" ]] && python3 -m json.tool "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$HOME_LIST_CACHE"
      return 0
    fi
  done

  rm -f "$tmp"
  return 1
}

home_python() {
  [[ -f "$HOME_LIST_CACHE" ]] || {
    return 1
  }
  python3 - "$HOME_LIST_CACHE" "$@"
}

home_list_count() {
  home_python count <<'PY' || printf '0\n'
import json
import sys

path = sys.argv[1]
mode = sys.argv[2]
try:
    data = json.load(open(path, "r", encoding="utf-8"))
except Exception:
    print(0)
    raise SystemExit

home_keys = {
    "home_id", "homeId", "home_name", "homeName",
    "family_id", "familyId", "family_name", "familyName",
}

def candidates(value, parent_key=""):
    if isinstance(value, list):
        if value and all(isinstance(item, dict) for item in value):
            parent = parent_key.lower()
            if "home" in parent or "famil" in parent:
                yield value
            elif any(home_keys.intersection(item.keys()) for item in value):
                yield value
        for item in value:
            yield from candidates(item, parent_key)
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from candidates(child, str(key))

groups = list(candidates(data))
print(max((len(group) for group in groups), default=0))
PY
}

print_home_list() {
  home_python list <<'PY' || true
import json
import sys

path = sys.argv[1]
mode = sys.argv[2]
try:
    data = json.load(open(path, "r", encoding="utf-8"))
except Exception:
    raise SystemExit

home_keys = {
    "home_id", "homeId", "home_name", "homeName",
    "family_id", "familyId", "family_name", "familyName",
}

def candidates(value, parent_key=""):
    if isinstance(value, list):
        if value and all(isinstance(item, dict) for item in value):
            parent = parent_key.lower()
            if "home" in parent or "famil" in parent:
                yield value
            elif any(home_keys.intersection(item.keys()) for item in value):
                yield value
        for item in value:
            yield from candidates(item, parent_key)
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from candidates(child, str(key))

groups = list(candidates(data))
if not groups:
    raise SystemExit

homes = max(groups, key=len)
for index, item in enumerate(homes, 1):
    name = (
        item.get("home_name") or item.get("homeName") or
        item.get("family_name") or item.get("familyName") or
        item.get("name") or "未命名家庭"
    )
    home_id = (
        item.get("home_id") or item.get("homeId") or
        item.get("family_id") or item.get("familyId") or
        item.get("id") or ""
    )
    suffix = f"（{home_id}）" if home_id else ""
    print(f"{index}. {name}{suffix}")
PY
}

target_home_info() {
  home_python find "$XINGUANG_TARGET_HOME" <<'PY'
import json
import sys

path = sys.argv[1]
mode = sys.argv[2]
target = sys.argv[3]
data = json.load(open(path, "r", encoding="utf-8"))

home_keys = {
    "home_id", "homeId", "home_name", "homeName",
    "family_id", "familyId", "family_name", "familyName",
}

def candidates(value, parent_key=""):
    if isinstance(value, list):
        if value and all(isinstance(item, dict) for item in value):
            parent = parent_key.lower()
            if "home" in parent or "famil" in parent:
                yield value
            elif any(home_keys.intersection(item.keys()) for item in value):
                yield value
        for item in value:
            yield from candidates(item, parent_key)
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from candidates(child, str(key))

def field(item, *names):
    for name in names:
        value = item.get(name)
        if value is not None and str(value) != "":
            return str(value)
    return ""

homes = []
for group in candidates(data):
    if len(group) > len(homes):
        homes = group

for item in homes:
    name = field(item, "home_name", "homeName", "family_name", "familyName", "name")
    home_id = field(item, "home_id", "homeId", "family_id", "familyId", "id")
    if name == target:
        print(f"{home_id}\t{name}")
        raise SystemExit(0)

raise SystemExit(1)
PY
}

current_home_matches_target() {
  local target_id="$1"
  local target_name="$2"
  rm -f "$CURRENT_HOME_CACHE"

  if have miloco-cli; then
    local args
    for args in \
      "scope home current --json" \
      "scope current --json" \
      "scope home status --json" \
      "scope status --json" \
      "scope home current" \
      "scope current"
    do
      if timeout 25s miloco-cli $args >"$CURRENT_HOME_CACHE" 2>/dev/null && [[ -s "$CURRENT_HOME_CACHE" ]]; then
        if grep -Fq "$target_name" "$CURRENT_HOME_CACHE" || { [[ -n "$target_id" ]] && grep -Fq "$target_id" "$CURRENT_HOME_CACHE"; }; then
          return 0
        fi
      fi
    done
  fi

  return 1
}

write_target_home_file() {
  local target_id="$1"
  local target_name="$2"
  umask 077
  {
    printf 'XINGUANG_TARGET_HOME=%s\n' "$target_name"
    printf 'XINGUANG_TARGET_HOME_ID=%s\n' "$target_id"
  } >"$TARGET_HOME_FILE"
  chmod 600 "$TARGET_HOME_FILE" 2>/dev/null || true
}

switch_to_target_home() {
  local target_id="$1"
  local target_name="$2"

  [[ -n "$target_id" ]] || die "未找到指定家庭，请检查家庭名称"
  have miloco-cli || die "检测到多个家庭，但当前工具未提供家庭选择能力，请先补充家庭选择功能后再继续。"

  state_mark HOME_SWITCH_STARTED
  if ! timeout 60s miloco-cli scope home switch "$target_id" >"$HOME_SWITCH_RESULT" 2>&1; then
    state_mark HOME_SWITCH_FAILED
    die "家庭切换失败，请检查目标家庭名称后再继续。"
  fi

  if current_home_matches_target "$target_id" "$target_name"; then
    write_target_home_file "$target_id" "$target_name"
    state_mark HOME_SWITCH_DONE
    printf '\n当前家庭已切换为：%s\n' "$target_name"
    return 0
  fi

  state_mark HOME_SWITCH_FAILED
  die "家庭切换后未能确认当前启用家庭，请联系技术人员处理。"
}

check_home_selection_before_install() {
  state_mark HOME_SELECTION_CHECK_START

  if ! have python3; then
    state_mark HOME_SELECTION_REQUIRED
    die "无法确认米家家庭列表，请先补充家庭列表查询和家庭选择功能后再继续。"
  fi

  if ! query_home_list; then
    state_mark HOME_SELECTION_REQUIRED
    die "无法确认米家家庭列表，请先补充家庭列表查询和家庭选择功能后再继续。"
  fi

  local count
  count="$(home_list_count)"
  if [[ -n "$XINGUANG_TARGET_HOME" ]]; then
    local target_line target_id target_name
    if ! target_line="$(target_home_info)"; then
      printf '\n检测到的米家家庭：\n'
      print_home_list
      state_mark TARGET_HOME_NOT_FOUND
      die "未找到指定家庭，请检查家庭名称"
    fi
    IFS=$'\t' read -r target_id target_name <<<"$target_line"
    switch_to_target_home "$target_id" "$target_name"
    return 0
  fi

  if [[ "$count" =~ ^[0-9]+$ ]] && (( count == 1 )); then
    state_mark HOME_SELECTION_SINGLE_HOME_AUTO
    return 0
  fi

  if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 1 )); then
    printf '\n检测到多个米家家庭：\n'
    print_home_list
    printf '\n请指定要控制馨光设备的家庭，例如：XINGUANG_TARGET_HOME="林坞店"\n'
    state_mark HOME_SELECTION_REQUIRED
    die "检测到多个米家家庭，请先选择要控制馨光设备的家庭，不要自动使用第一个家庭。"
  fi

  state_mark HOME_SELECTION_REQUIRED
  die "无法确认米家家庭列表，请先补充家庭列表查询和家庭选择功能后再继续。"
}

analyze_devices() {
  python3 - "$DEVICE_CACHE" "$TARGET_DEVICE_FILE" "$DEVICE_REPORT" \
    "$XINGUANG_TARGET_HOME" "$XINGUANG_TARGET_ROOM" "$XINGUANG_TARGET_DEVICE_NAME" "$XINGUANG_TARGET_PRODUCT" <<'PY'
import json
import sys

device_path, target_path, report_path, target_home, target_room, target_name, target_product = sys.argv[1:8]

try:
    raw = json.load(open(device_path, "r", encoding="utf-8"))
except Exception as exc:
    print(f"STATUS\tquery_failed")
    print(f"MESSAGE\t设备列表解析失败：{exc}")
    raise SystemExit

def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for item in value:
            yield from walk(item)

def field(obj, *names):
    for name in names:
        value = obj.get(name)
        if value is not None and str(value) != "":
            return str(value)
    return ""

def online_state(obj):
    for key in ("online", "is_online", "isOnline", "isOnlineDevice", "available"):
        if key in obj:
            value = obj[key]
            if isinstance(value, bool):
                return value
            if str(value).lower() in ("1", "true", "online", "yes", "在线"):
                return True
            if str(value).lower() in ("0", "false", "offline", "no", "离线"):
                return False
    for key in ("status", "deviceStatus", "connect_status", "connectionStatus"):
        if key in obj:
            value = str(obj[key]).lower()
            if value in ("online", "1", "true", "在线", "connected"):
                return True
            if value in ("offline", "0", "false", "离线", "disconnected"):
                return False
    return None

def text_blob(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True).lower()

cap_groups = {
    "开关": ("开关", "switch", "onoff", "power"),
    "亮度": ("亮度", "brightness", "bright"),
    "RGB 彩色": ("rgb", "彩色", "color", "colour"),
    "色温": ("色温", "color_temp", "color temperature", "ct"),
    "饱和度": ("饱和", "saturation", "saturat"),
    "色彩模式": ("色彩模式", "color_mode", "colour_mode"),
    "模式": ("模式", "mode"),
}

def caps(obj):
    blob = text_blob(obj)
    matched = []
    for label, words in cap_groups.items():
        if any(word.lower() in blob for word in words):
            matched.append(label)
    return matched

def model_value(obj):
    return field(obj, "model", "modelName", "model_name", "deviceModel", "productModel", "product_model")

def normalize(obj):
    name = field(obj, "name", "device_name", "deviceName", "displayName", "title")
    did = field(obj, "did", "id", "device_id", "deviceId", "miotDid")
    room = field(obj, "room", "room_name", "roomName", "room_name_cn", "parentRoomName", "area")
    model = model_value(obj)
    matched_caps = caps(obj)
    online = online_state(obj)
    blob = text_blob(obj)
    model_match = model == "wainft.light.rgbcwy" or "wainft.light.rgbcwy" in blob
    caps_match = len(matched_caps) >= 5 and all(label in matched_caps for label in ("开关", "亮度", "RGB 彩色"))
    name_keyword = any(word in name.lower() for word in ("馨光", "xg", "rgbcw"))
    return {
        "name": name,
        "did": did,
        "room": room,
        "model": model,
        "online": online,
        "caps": matched_caps,
        "model_match": model_match,
        "caps_match": caps_match,
        "name_keyword": name_keyword,
        "raw": obj,
    }

devices = []
seen = set()
for obj in walk(raw):
    if not isinstance(obj, dict):
        continue
    item = normalize(obj)
    if not item["name"] and not item["did"] and not item["model"]:
        continue
    key = item["did"] or f'{item["name"]}|{item["room"]}|{item["model"]}|{len(devices)}'
    if key in seen:
        continue
    seen.add(key)
    devices.append(item)

def online_text(value):
    if value is True:
        return "在线"
    if value is False:
        return "离线"
    return "未确认"

def result_name(item):
    if item["model_match"]:
        return "馨光RGBCW幻彩灯带 / 灯膜"
    if item["caps_match"]:
        return "疑似馨光RGBCW幻彩灯带 / 灯膜"
    if item["name_keyword"]:
        return "名称疑似馨光设备"
    return "未归类"

def report_items(items):
    lines = []
    for index, item in enumerate(items, 1):
        caps_summary = "、".join(item["caps"]) if item["caps"] else "未识别"
        model = item["model"] or "未返回"
        room = item["room"] or "未返回"
        lines.append(
            f'{index}. 设备：{item["name"] or "未命名"}；房间：{room}；'
            f'在线状态：{online_text(item["online"])}；model：{model}；'
            f'能力摘要：{caps_summary}；识别结果：{result_name(item)}'
        )
    return "\n".join(lines)

def save_target(item):
    public = {
        "name": item["name"],
        "room": item["room"],
        "model": item["model"],
        "online": online_text(item["online"]),
        "caps": item["caps"],
        "result": result_name(item),
        "target_home": target_home,
        "target_product": target_product,
    }
    private = dict(public)
    private["did"] = item["did"]
    json.dump(private, open(target_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    with open(report_path, "w", encoding="utf-8") as handle:
        handle.write(report_items([item]) + "\n")

def emit_ready(item, explicit):
    states = ["TARGET_DEVICE_FOUND"]
    if target_room:
        states.append("TARGET_ROOM_SET")
    if target_name:
        states.append("TARGET_DEVICE_NAME_SET")
    if item["model_match"]:
        states.append("TARGET_DEVICE_MODEL_MATCHED")
    else:
        states.append("TARGET_DEVICE_MODEL_UNAVAILABLE")
    if item["caps_match"]:
        states.append("TARGET_DEVICE_CAPS_MATCHED")
    if explicit and item["caps_match"] and not item["model_match"]:
        states.append("TARGET_DEVICE_NEEDS_CONFIRMATION")
    states.append("TARGET_DEVICE_READY")
    save_target(item)
    for state in states:
        print(f"STATE\t{state}")
    print("STATUS\tready")
    print(f'MESSAGE\t目标设备已确认：{item["name"] or "未命名"}，房间：{item["room"] or "未返回"}，状态：{online_text(item["online"])}，识别结果：{result_name(item)}')

def fail(status, state, message, items=None):
    if items:
        with open(report_path, "w", encoding="utf-8") as handle:
            handle.write(report_items(items) + "\n")
        print("INFO\t候选设备列表：")
        for line in report_items(items).splitlines():
            print(f"INFO\t{line}")
    print(f"STATE\t{state}")
    print(f"STATUS\t{status}")
    print(f"MESSAGE\t{message}")

if target_room:
    print("STATE\tTARGET_ROOM_SET")
if target_name:
    print("STATE\tTARGET_DEVICE_NAME_SET")

scope = devices
if target_room:
    room_matches = [item for item in scope if item["room"] == target_room]
    if room_matches:
        scope = room_matches

if target_name:
    matches = [item for item in scope if item["name"] == target_name]
    if not matches:
        fail("not_found", "TARGET_PRODUCT_NOT_FOUND", "未找到指定设备，请检查房间和设备名称。", scope[:12])
        raise SystemExit
    if len(matches) > 1:
        fail("selection_required", "DEVICE_SELECTION_REQUIRED", "找到多个同名设备，请选择具体设备，不要自动使用第一个设备。", matches)
        raise SystemExit
    selected = matches[0]
    if selected["online"] is False:
        fail("offline", "TARGET_DEVICE_OFFLINE", "目标设备当前离线，请先确认设备已通电并联网。", [selected])
        raise SystemExit
    if selected["model_match"] or selected["caps_match"]:
        emit_ready(selected, True)
        raise SystemExit
    fail("cap_mismatch", "TARGET_PRODUCT_NOT_FOUND", "目标设备能力不匹配，请重新选择馨光RGBCW幻彩灯带 / 灯膜设备。", [selected])
    raise SystemExit

candidates = [item for item in scope if item["model_match"] or item["caps_match"]]
candidates = [item for item in candidates if item["online"] is not False]

if not candidates:
    fail("not_found", "TARGET_PRODUCT_NOT_FOUND", "未发现可用的馨光RGBCW幻彩灯带 / 灯膜设备，请选择具体设备后再继续。", scope[:12])
elif len(candidates) > 1:
    fail("selection_required", "DEVICE_SELECTION_REQUIRED", "发现多个候选灯光设备，请选择具体设备，不要自动使用第一个设备。", candidates)
else:
    emit_ready(candidates[0], False)
PY
}

query_devices() {
  load_env_if_present
  rm -f "$DEVICE_CACHE" "$TARGET_DEVICE_FILE" "$DEVICE_REPORT"
  state_mark DEVICE_DISCOVERY_STARTED
  if curl -fsS --max-time 20 \
    -H "Authorization: Bearer $WAINFORT_API_TOKEN" \
    "http://127.0.0.1:$WAINFORT_API_PORT/api/devices" \
    -o "$DEVICE_CACHE"; then
    state_mark DEVICE_QUERY_DONE
    state_mark DEVICE_DISCOVERY_DONE

    local status="" message="" kind value
    while IFS=$'\t' read -r kind value; do
      case "$kind" in
        STATE) state_mark "$value" ;;
        STATUS) status="$value" ;;
        MESSAGE) message="$value" ;;
        INFO) printf '%s\n' "$value" ;;
      esac
    done < <(analyze_devices)

    case "$status" in
      ready)
        state_mark XINGUANG_DEVICE_FOUND
        printf '\n%s\n' "$message"
        return 0
        ;;
      selection_required|not_found|offline|cap_mismatch)
        die "$message"
        ;;
      *)
        die "设备识别失败，请联系技术人员处理。"
        ;;
    esac
  fi

  state_mark DEVICE_QUERY_FAILED
  die "暂时无法查询设备，请先确认米家账号已绑定，并且稍后发送“查看馨光 Skill 安装进度”。"
}

check_first_stage_ready() {
  have openclaw || die "请先完成第一阶段安装，再继续安装馨光 Skill。"
  have miloco-cli || die "请先完成第一阶段安装，并确认小龙虾相关命令可用。"
  state_mark FIRST_STAGE_READY
}

print_status() {
  load_env_if_present
  printf '馨光 Skill 安装进度\n\n'
  printf '检查时间：%s\n' "$(date '+%F %T %Z')"
  printf '安装器版本：%s\n' "$XINGUANG_SKILL_INSTALLER_VERSION"
  printf 'Skill 版本：%s\n' "$XINGUANG_SKILL_VERSION"
  printf '状态文件：%s\n' "$STATE_FILE"
  printf '日志文件：%s\n\n' "$LOG_FILE"

  if [[ -f "$STATE_FILE" ]]; then
    printf '最近状态：\n'
    tail -n 40 "$STATE_FILE" || true
  else
    printf '最近状态：暂未找到状态文件\n'
  fi

  printf '\n服务状态：'
  if server_status_ok || server_process_running; then
    printf '运行中\n'
  else
    printf '未确认运行\n'
  fi

  printf 'Skill 文件：'
  if [[ -f "$LOCAL_SKILL_FILE" ]] || status_file_has SKILL_INSTALL_DONE; then
    printf '已准备\n'
  else
    printf '未确认\n'
  fi

  if [[ -f "$TARGET_HOME_FILE" ]]; then
    printf '\n当前家庭：'
    grep -E '^XINGUANG_TARGET_HOME=' "$TARGET_HOME_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || printf '未确认'
    printf '\n'
  elif [[ -n "$XINGUANG_TARGET_HOME" ]]; then
    printf '\n目标家庭：%s\n' "$XINGUANG_TARGET_HOME"
  fi

  if [[ -f "$HOME_LIST_CACHE" ]]; then
    printf '\n检测到的家庭列表：\n'
    print_home_list
  fi

  if status_file_has HOME_SELECTION_REQUIRED; then
    printf '\n家庭选择：需要处理\n'
    printf '说明：检测到多个米家家庭，请先选择要控制馨光设备的家庭，不要自动使用第一个家庭。\n'
  fi
  if status_file_has TARGET_HOME_NOT_FOUND; then
    printf '\n家庭选择：未找到指定家庭，请检查家庭名称。\n'
  fi

  printf '\n目标房间：%s\n' "${XINGUANG_TARGET_ROOM:-未指定}"
  printf '目标设备名称：%s\n' "${XINGUANG_TARGET_DEVICE_NAME:-未指定}"
  printf '目标产品：%s\n' "${XINGUANG_TARGET_PRODUCT:-馨光RGBCW幻彩灯带}"

  if [[ -f "$DEVICE_REPORT" ]]; then
    printf '\n设备识别结果：\n'
    cat "$DEVICE_REPORT" || true
  fi

  if status_file_has DEVICE_SELECTION_REQUIRED; then
    printf '\n设备选择：发现多个候选灯光设备，请选择具体设备，不要自动使用第一个设备。\n'
  fi
  if status_file_has TARGET_PRODUCT_NOT_FOUND; then
    printf '\n设备选择：未找到符合条件的目标设备，请检查家庭、房间和设备名称。\n'
  fi
  if status_file_has TARGET_DEVICE_OFFLINE; then
    printf '\n设备选择：目标设备当前离线，请先确认设备已通电并联网。\n'
  fi
  if status_file_has TARGET_DEVICE_NEEDS_CONFIRMATION; then
    printf '\n设备识别：model 未返回，已按设备能力归类为疑似馨光RGBCW幻彩灯带 / 灯膜。\n'
  fi
  if status_file_has TARGET_DEVICE_READY; then
    printf '\n设备选择：目标设备已确认，可以进入灯光控制测试。\n'
  fi

  printf '馨光设备：'
  if status_file_has TARGET_DEVICE_READY || status_file_has XINGUANG_DEVICE_FOUND; then
    printf '已确认\n'
  else
    printf '未确认\n'
  fi

  printf '\n最近错误：\n'
  grep -Ei 'ERROR|失败|未能|无法|not found|failed|traceback' "$STATE_FILE" "$LOG_FILE" 2>/dev/null | tail -n 20 || printf '未发现明显错误\n'
}

main() {
  if [[ "$INSTALL_ACTION" == "status" ]]; then
    print_status
    return 0
  fi
  if [[ "$INSTALL_ACTION" != "full" && "$INSTALL_ACTION" != "continue" ]]; then
    die "未知安装动作：$INSTALL_ACTION"
  fi

  printf '%s\n' "$$" >"$PID_FILE"
  state_mark "INSTALLER_VERSION=$XINGUANG_SKILL_INSTALLER_VERSION"
  state_mark "SKILL_VERSION=$XINGUANG_SKILL_VERSION"

  check_first_stage_ready
  check_home_selection_before_install
  ensure_env_file
  download_skill
  download_server
  start_server
  install_skill
  query_devices

  state_mark XINGUANG_SKILL_INSTALL_DONE
  printf '\n馨光 Skill 安装流程已完成\n'
  printf '安装器版本：%s\n' "$XINGUANG_SKILL_INSTALLER_VERSION"
  printf 'Skill 版本：%s\n' "$XINGUANG_SKILL_VERSION"
  [[ -n "$XINGUANG_TARGET_HOME" ]] && printf '当前家庭：%s\n' "$XINGUANG_TARGET_HOME"
  [[ -n "$XINGUANG_TARGET_ROOM" ]] && printf '目标房间：%s\n' "$XINGUANG_TARGET_ROOM"
  [[ -n "$XINGUANG_TARGET_DEVICE_NAME" ]] && printf '目标设备：%s\n' "$XINGUANG_TARGET_DEVICE_NAME"
  [[ -f "$DEVICE_REPORT" ]] && { printf '\n设备识别结果：\n'; cat "$DEVICE_REPORT"; }
  printf '日志文件：%s\n' "$LOG_FILE"
  printf '状态文件：%s\n' "$STATE_FILE"
  printf '\n下一步：请确认后再发送灯光测试语句。安装流程不会自动控制灯光。\n'
}

main "$@"

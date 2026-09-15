# Hostinger LINE Hermes Bootstrap

這個 repo 是給「Hostinger 一鍵部署 Hermes Agent」後使用的 LINE Messaging API 快速套用包。

如果你是被使用者要求處理這個 repo 的 **Hermes Agent / AI coding agent**：請先讀本 README，然後照「Agent 執行指引」帶使用者完成模型選擇、LINE credentials 填入、安裝、重啟與驗證。不要要求使用者把 secret/token 貼到聊天訊息裡。

## 目標

客戶透過 Hostinger 一鍵部署 Hermes Agent 後，部署者可以 clone 這個 repo，執行 installer，完成：

1. 安裝已驗證的 LINE platform plugin。
2. 套用 Hostinger + LINE 建議的 Hermes config 預設值。
3. 檢查/修正 Traefik LINE route，確保 `/line/webhook` 與 `/line/media/...` 都會進到 LINE adapter。
4. 引導使用者選擇 Hermes 模型/provider。
5. 引導使用者把 LINE channel access token、channel secret、public URL 安全寫入 `/opt/data/.env`。
6. 重啟 Hermes container/gateway 後，完成 local/public health、LINE Developers webhook verify、實際 LINE 訊息回覆測試。

## 不包含

- 部署者自己的業務資料或個人資料。
- 客戶業務資料。
- 客戶 LINE access token / secret。
- ADMIN_PASSWORD 或任何 API key。
- 任何個人化 persona、memory 或歷史 session。

## Agent 執行指引

### 0. 先確認環境與邊界

你正在協助使用者把 Hostinger one-click Hermes Agent 串接到 LINE Messaging API。請先確認：

- 使用者已經在 Hostinger 建立 Hermes Agent VPS/container。
- 使用者目前終端機可以進入 Hermes container，且看得到 `/opt/data` 與 `/opt/hermes`。
- repo 已 clone 到 `/opt/data/hostinger_line_implementation`，或你要帶使用者 clone。
- 不要讀取、列印或保存任何 secret；只回報 `SET` / `MISSING`。
- 修改正式檔案前先備份，尤其是 `/opt/data/.env`、`/opt/data/config.yaml`、`/opt/hermes/plugins/platforms/line/*`。

建議先執行：

```bash
whoami
id
pwd
ls -ld /opt/data /opt/hermes
command -v hermes || true
```

### 1. 引導使用者選擇 Hermes 模型/provider

如果 Hermes 尚未設定模型，請帶使用者執行 Hermes 官方互動式設定，不要手動猜 config 格式：

```bash
hermes model
```

或：

```bash
hermes setup model
```

給使用者的簡短建議：

- 想最快開始、可用多模型：選 OpenRouter，貼入 OpenRouter API key。
- 已有 OpenAI / Gemini / Anthropic key：選對應 provider。
- 若 Hermes 支援並且使用者要 OAuth：照 `hermes model` 畫面完成登入。

模型設定後，做一次最小測試：

```bash
hermes chat -q "請只回覆 OK"
```

如果這一步失敗，先修模型/provider/API key，不要先排查 LINE。

### 2. 引導使用者準備 LINE Messaging API 資訊

請使用者到 LINE Developers Console 建立或打開 Messaging API channel：

```text
https://developers.line.biz/console/
```

需要取得：

- `LINE_CHANNEL_ACCESS_TOKEN`：Messaging API > Channel access token。
- `LINE_CHANNEL_SECRET`：Basic settings > Channel secret。
- `LINE_PUBLIC_URL`：Hostinger 給 Hermes WebUI 的 public HTTPS base URL，例如 `https://<project>.<hostinger-domain>`。

注意：

- `LINE_PUBLIC_URL` 是 base URL，不要加 `/line/webhook`。
- 最後 LINE Developers webhook URL 才是 `<LINE_PUBLIC_URL>/line/webhook`。
- 請使用者只把 token/secret 貼到終端機 prompt 或編輯器，不要貼在聊天裡。

### 3. 安全寫入 `/opt/data/.env`

如果 `/opt/data/.env` 已存在，先備份：

```bash
cp /opt/data/.env "/opt/data/.env.bak.$(date +%Y%m%d_%H%M%S)"
```

如果不存在，從範本建立：

```bash
cp templates/env.template /opt/data/.env
chmod 600 /opt/data/.env
```

建議用互動式終端機安全寫入 LINE 變數。請在 repo 目錄執行：

```bash
cd /opt/data/hostinger_line_implementation

read -rsp "LINE channel access token: " LINE_CHANNEL_ACCESS_TOKEN; echo
read -rsp "LINE channel secret: " LINE_CHANNEL_SECRET; echo
read -rp "LINE public base URL (no /line/webhook): " LINE_PUBLIC_URL
export LINE_CHANNEL_ACCESS_TOKEN LINE_CHANNEL_SECRET LINE_PUBLIC_URL

python3 - <<'PY'
from pathlib import Path
import os

path = Path('/opt/data/.env')
path.touch(mode=0o600, exist_ok=True)
values = {
    'LINE_CHANNEL_ACCESS_TOKEN': os.environ['LINE_CHANNEL_ACCESS_TOKEN'],
    'LINE_CHANNEL_SECRET': os.environ['LINE_CHANNEL_SECRET'],
    'LINE_PUBLIC_URL': os.environ['LINE_PUBLIC_URL'].rstrip('/'),
    'LINE_HOST': '0.0.0.0',
    'LINE_PORT': '8646',
    'LINE_ALLOW_ALL_USERS': 'true',
}
lines = path.read_text().splitlines() if path.exists() else []
seen = set()
out = []
for line in lines:
    if '=' not in line or line.lstrip().startswith('#'):
        out.append(line)
        continue
    key = line.split('=', 1)[0].strip()
    if key in values:
        out.append(f'{key}={values[key]}')
        seen.add(key)
    else:
        out.append(line)
for key, value in values.items():
    if key not in seen:
        out.append(f'{key}={value}')
path.write_text('\n'.join(out).rstrip() + '\n')
path.chmod(0o600)
print('LINE env updated: SET values written to /opt/data/.env')
PY

unset LINE_CHANNEL_ACCESS_TOKEN LINE_CHANNEL_SECRET LINE_PUBLIC_URL
```

驗證時只印 `SET` / `MISSING`，不要印 secret：

```bash
bash scripts/verify-line.sh --skip-health
```

### 4. Clone repo

目前 repo 是 public，可直接 clone：

```bash
cd /opt/data
git clone https://github.com/jimmyhsu1010/hostinger_line_implementation.git
cd hostinger_line_implementation
```

如果之後改回 private，請看：

```text
docs/private-repo-access.md
```

### 5. 一鍵安裝 LINE plugin / config / route

在 repo 內執行：

```bash
cd /opt/data/hostinger_line_implementation
bash scripts/one-click-install.sh
```

這支 script 會做：

1. 建立/備份並安裝 `/opt/hermes/plugins/platforms/line/adapter.py` 與 `plugin.yaml`。
2. 套用安全的 Hermes config 預設值。
3. 若找得到 Hostinger compose，檢查/修正 LINE route 為 `PathPrefix('/line')`。
4. 驗證 LINE env 與 adapter 語法；預設略過 health，因為安裝後通常要先重啟 container/gateway。
5. 印出下一步 LINE Developers webhook URL。

舊名稱仍可用：

```bash
bash scripts/bootstrap.sh
```

`bootstrap.sh` 目前只是轉呼叫 `one-click-install.sh`。

### 6. 重啟 Hermes container/gateway

安裝 plugin/config 後必須重啟，讓 Hermes 載入新的 adapter 與 `.env`。

在 Hostinger/Docker host 上通常是：

```bash
docker restart <container_name>
```

如果是在 container 內，而且 gateway 是前景模式，請使用 Hostinger 控制台重啟 container，或依該環境的服務管理方式重啟。

### 7. 完整驗證

重啟後，在 repo 內執行：

```bash
bash scripts/verify-line.sh
```

會檢查：

- LINE env 是否存在。
- adapter.py 是否可編譯。
- 本機 health endpoint：`http://127.0.0.1:8646/line/webhook/health`。
- 公開 health endpoint：`<LINE_PUBLIC_URL>/line/webhook/health`。

公開 health 應該看到類似：

```json
{"status": "ok", "platform": "line"}
```

如果看到 dashboard HTML、login page、302 redirect 或 404，通常是 Traefik route 沒有把 `/line` 導到 port `8646`。

### 8. LINE Developers Console 設定

LINE Developers webhook URL 應填：

```text
<LINE_PUBLIC_URL>/line/webhook
```

並確認：

- Use webhook：enabled。
- Auto-reply / Greeting message 不要干擾 Hermes 回覆。
- Webhook verify 成功。

### 9. 實際 LINE 測試

請使用者用 LINE 傳一則短訊息給 Official Account，例如：

```text
請只回覆 OK
```

完成標準：

- LINE Developers webhook verify 成功。
- 使用者傳 LINE 訊息後，Hermes 有回覆。
- `bash scripts/verify-line.sh` 通過。
- 若要測圖片/檔案/語音，確認 `/line/media/...` 也由 LINE adapter 處理，而不是被導到 dashboard/login。

## 標準使用情境

客戶已透過 Hostinger 一鍵部署 Hermes Agent，且 Hostinger 產生的設定通常類似：

- WebUI / Dashboard port: 4860
- LINE adapter port: 8646
- volume: `./data:/opt/data`
- image: `ghcr.io/hostinger/hvps-hermes-agent:latest`
- Traefik LINE router: `PathPrefix('/line')`

目前標準化後，Traefik LINE route 應該使用：

```yaml
PathPrefix(`/line`)
```

不是：

```yaml
PathPrefix(`/line/webhook`)
```

原因：`/line/webhook` 只涵蓋 webhook 與 health；LINE 圖片、影片、音訊或檔案預覽可能會使用 `/line/media/...`，所以 route 要涵蓋整個 `/line`。

## 客戶 .env 必填

不要把真實 token commit 到 GitHub。可參考：

```text
templates/env.template
```

至少填入：

```env
LINE_CHANNEL_ACCESS_TOKEN=...
LINE_CHANNEL_SECRET=...
LINE_PUBLIC_URL=https://<compose-project>.<traefik-host>
LINE_HOST=0.0.0.0
LINE_PORT=8646
LINE_ALLOW_ALL_USERS=true
```

注意：`LINE_PUBLIC_URL` 是 base URL，不要加 `/line/webhook`。

`LINE_ALLOW_ALL_USERS=true` 適合客戶自己的公開 OA 初始測試。若是私人/內部 bot，再改成 allowlist。

## config.yaml

這個 repo 不直接覆蓋客戶的 `/opt/data/config.yaml`，避免刪掉 Hostinger 一鍵部署已產生的設定。

一鍵 script 會用 `hermes config set ...` 只改必要項目。

人類可讀參考：

```text
templates/config.yaml
```

## 手動驗證指令

安裝前只檢查 env 與 adapter 語法：

```bash
bash scripts/verify-line.sh --skip-health
```

重啟後做完整驗證：

```bash
bash scripts/verify-line.sh
```

LINE Developers webhook URL 應填：

```text
https://<LINE_PUBLIC_URL_HOST>/line/webhook
```

health URL：

```text
https://<LINE_PUBLIC_URL_HOST>/line/webhook/health
```

## 檔案說明

```text
line/adapter.py                         已驗證 LINE adapter
line/plugin.yaml                        LINE platform plugin metadata
scripts/one-click-install.sh             一鍵套用 adapter/config/route/verify
scripts/bootstrap.sh                     相容舊名稱，轉呼叫 one-click-install.sh
scripts/install-line-adapter.sh          安裝 /opt/hermes 的 LINE plugin，並備份原檔
scripts/configure-hostinger-line.sh      套用 Hermes config 基本設定
scripts/fix-traefik-line-route.sh        將舊 PathPrefix('/line/webhook') 修成 PathPrefix('/line')
scripts/verify-line.sh                   驗證 env、adapter、health
templates/env.template                   客戶 .env 範本，不含秘密
templates/config.yaml                    config.yaml 參考值，不直接覆蓋正式設定
templates/docker-compose.hostinger.yml   Hostinger compose 範例，LINE route 已使用 PathPrefix('/line')
templates/handover.md                    交付給客戶的簡短說明
docs/hostinger-line-sop.md               部署 SOP
docs/private-repo-access.md              private repo clone/access 說明
tests/test_bootstrap.py                  bootstrap 與 adapter smoke tests
```

## 安全提醒

- 不要 commit `.env`。
- 不要把 LINE token / secret / password / API key 貼到聊天訊息。
- 不要 commit 客戶 token、secret、password、API key。
- 若曾把 secret 貼到聊天或 repo，請立刻旋轉。
- 修改 `/opt/hermes/plugins/platforms/line/adapter.py` 前 script 會自動備份。
- 若 repo 之後改回 private，clone 用的 PAT 建議短效、只給 Contents Read-only。
- clone 完若 remote URL 帶 token，請改回乾淨 URL：

```bash
git remote set-url origin https://github.com/jimmyhsu1010/hostinger_line_implementation.git
```

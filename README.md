# Hostinger LINE Hermes Bootstrap

這個 repo 是給「Hostinger 一鍵部署 Hermes Agent」後使用的快速套用包。

目的：

1. 保留已在實機驗證過的 LINE adapter。
2. 快速修正 Hostinger Traefik LINE route。
3. 快速套用適合 LINE OA 的 Hermes 基本設定。
4. 驗證 LINE webhook health 與本機 adapter 狀態。

不包含：

- 部署者自己的業務資料或個人資料。
- 客戶業務資料。
- 客戶 LINE access token / secret。
- ADMIN_PASSWORD 或任何 API key。

## 標準使用情境

客戶已透過 Hostinger 一鍵部署 Hermes Agent，且 compose 類似：

- WebUI / Dashboard port: 4860
- LINE adapter port: 8646
- volume: `./data:/opt/data`
- image: `ghcr.io/hostinger/hvps-hermes-agent:latest`

接著進入該 Hermes container 或在可修改 `/opt/hermes` 的環境中執行 bootstrap script。

## 最快安裝方式

正式推到 GitHub 後，可用：

```bash
export REPO_RAW_BASE="https://raw.githubusercontent.com/<你的GitHub帳號>/hostinger_line_implementation/main"
curl -fsSL "$REPO_RAW_BASE/scripts/bootstrap.sh" | bash
```

如果 repo 已經 clone 到機器上：

```bash
cd /opt/data/hostinger_line_implementation
bash scripts/bootstrap.sh
```

## 客戶 .env 必填

不要把真實 token commit 到 GitHub。請複製模板：

```bash
cp templates/env.template /opt/data/.env
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

`LINE_ALLOW_ALL_USERS=true` 適合客戶自己的公開 OA 初始測試。若是私人/內部 bot，再改成 allowlist。

## Hostinger compose 重要修正

LINE route 建議使用：

```yaml
PathPrefix(`/line`)
```

不要只用：

```yaml
PathPrefix(`/line/webhook`)
```

原因是 `/line/webhook` 只涵蓋 webhook 與 health，但圖片/音訊/影片可能需要 `/line/media/...`，如果沒有轉到 8646，LINE 會顯示圖片或媒體失敗。

可執行：

```bash
bash scripts/fix-traefik-line-route.sh /path/to/docker-compose.yml
```

## 驗證

```bash
bash scripts/verify-line.sh
```

會檢查：

- LINE env 是否存在。
- adapter.py 是否可編譯。
- 本機 health endpoint。
- 公開 health endpoint。

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
scripts/install-line-adapter.sh          覆蓋 /opt/hermes 的 adapter，並備份原檔
scripts/configure-hostinger-line.sh      套用 Hermes config 基本設定
scripts/fix-traefik-line-route.sh        把 PathPrefix(`/line/webhook`) 改成 PathPrefix(`/line`)
scripts/verify-line.sh                   驗證 env、adapter、health
scripts/bootstrap.sh                     串起 install + configure + verify
templates/env.template                   客戶 .env 範本，不含秘密
templates/docker-compose.hostinger.yml   Hostinger compose 範例
templates/handover.md                    交付給客戶的簡短說明
```

## 安全提醒

- 不要 commit `.env`。
- 不要 commit 客戶 token、secret、password、API key。
- 若曾把 secret 貼到聊天或 repo，請立刻旋轉。
- 修改 `/opt/hermes/plugins/platforms/line/adapter.py` 前 script 會自動備份。

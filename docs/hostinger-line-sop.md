# Hostinger LINE Hermes 部署 SOP

## 0. 前提

客戶已經透過 Hostinger 一鍵部署 Hermes Agent。

Hostinger 生成的 compose 通常會有：

- WebUI: 4860
- LINE adapter: 8646
- volume: `./data:/opt/data`
- Traefik host: `${COMPOSE_PROJECT_NAME}.${TRAEFIK_HOST}`

## 1. 填入客戶 LINE env

在客戶 Hermes 專案的 `.env` 填入：

```env
LINE_CHANNEL_ACCESS_TOKEN=...
LINE_CHANNEL_SECRET=...
LINE_PUBLIC_URL=https://<customer-host>
LINE_HOST=0.0.0.0
LINE_PORT=8646
LINE_ALLOW_ALL_USERS=true
```

注意：`LINE_PUBLIC_URL` 不要加 `/line/webhook`。

## 2. 修 Hostinger Traefik LINE route

若 compose 目前是：

```text
PathPrefix(`/line/webhook`)
```

改成：

```text
PathPrefix(`/line`)
```

這樣 `/line/media/...` 也會轉到 LINE adapter。

可用：

```bash
bash scripts/fix-traefik-line-route.sh /path/to/docker-compose.yml
```

## 3. 套用 adapter 與設定

在 container 內或可寫 `/opt/hermes` 的環境中：

```bash
bash scripts/bootstrap.sh
```

若從 GitHub raw 執行：

```bash
export REPO_RAW_BASE="https://raw.githubusercontent.com/<owner>/hostinger_line_implementation/main"
curl -fsSL "$REPO_RAW_BASE/scripts/bootstrap.sh" | bash
```

## 4. 重啟

```bash
docker restart <container_name>
```

或從 Hostinger 控制台重啟。

## 5. 驗證

```bash
bash scripts/verify-line.sh
```

確認公開 health：

```text
https://<customer-host>/line/webhook/health
```

應該看到 LINE adapter JSON，而不是 dashboard HTML / login page。

## 6. LINE Developers

Webhook URL：

```text
https://<customer-host>/line/webhook
```

確認：

- Use webhook enabled
- Auto-reply 不要干擾 Hermes 回覆
- 客戶用 LINE 傳訊息會收到 Hermes 回覆

## 7. 交付

交付給客戶：

- WebUI URL
- LINE webhook URL
- `/opt/data` 是他的資料目錄
- `.env` 不可外洩
- 如果 token 外洩，要去 LINE Developers 重新發行

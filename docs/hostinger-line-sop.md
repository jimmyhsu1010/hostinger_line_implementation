# Hostinger LINE Hermes 部署 SOP

## 0. 前提

客戶已經透過 Hostinger 一鍵部署 Hermes Agent。

Hostinger 生成的 compose 通常會有：

- WebUI: 4860
- LINE adapter: 8646
- volume: `./data:/opt/data`
- Traefik host: `${COMPOSE_PROJECT_NAME}.${TRAEFIK_HOST}`
- LINE route 應為 `PathPrefix('/line')`

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

## 2. 取得 private repo

因 repo 是 private，先用短效 fine-grained PAT 或 SSH deploy key clone。

最短流程：

```bash
cd /opt/data
read -rsp "GitHub token: " GH_PAT; echo
export GH_PAT
tmp_askpass="$(mktemp)"
cat > "$tmp_askpass" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  Username*) echo x-access-token ;;
  Password*) echo "$GH_PAT" ;;
esac
EOF
chmod 700 "$tmp_askpass"
GIT_ASKPASS="$tmp_askpass" GIT_TERMINAL_PROMPT=0 git clone https://github.com/jimmyhsu1010/hostinger_line_implementation.git
rm -f "$tmp_askpass"
unset GH_PAT
cd hostinger_line_implementation
git remote set-url origin https://github.com/jimmyhsu1010/hostinger_line_implementation.git
```

詳細見：

```text
docs/private-repo-access.md
```

## 3. 一鍵套用 adapter/config/route/verify

```bash
bash scripts/one-click-install.sh
```

這會：

1. 安裝本 repo 的 `line/adapter.py` 到 `/opt/hermes/plugins/platforms/line/adapter.py`。
2. 套用基本 Hermes config。
3. 檢查 Hostinger compose；若還是 `PathPrefix('/line/webhook')`，會改成 `PathPrefix('/line')`。
4. 執行 health 驗證。

如果 compose 不在自動搜尋位置，可以指定：

```bash
COMPOSE_FILE=/path/to/docker-compose.yml bash scripts/one-click-install.sh
```

如果你是在 container 內 clone repo，通常看不到 host 的 compose，script 會略過 route 修改。這時請在 Hostinger/host 端確認 LINE route 已經是 `PathPrefix('/line')`。

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

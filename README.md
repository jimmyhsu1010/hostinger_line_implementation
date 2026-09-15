# Hostinger LINE Hermes Bootstrap

這個 repo 是給「Hostinger 一鍵部署 Hermes Agent」後使用的快速套用包。

目標：客戶透過 Hostinger 一鍵部署 Hermes Agent 後，部署者只要 clone 這個 repo，執行一個 script，就能套用已驗證的 LINE platform plugin、基本 config、檢查 Hostinger Traefik LINE route，並完成安裝前驗證。

不包含：

- 部署者自己的業務資料或個人資料。
- 客戶業務資料。
- 客戶 LINE access token / secret。
- ADMIN_PASSWORD 或任何 API key。
- 任何個人化 persona、memory 或歷史 session。

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

## Clone repo

目前 repo 是 public，可直接 clone：

```bash
cd /opt/data
git clone https://github.com/jimmyhsu1010/hostinger_line_implementation.git
cd hostinger_line_implementation
bash scripts/one-click-install.sh
```

如果之後改回 private，最快方式是使用短效 fine-grained PAT，只給這個 repo 的 Contents Read-only 權限：

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
bash scripts/one-click-install.sh
```

更多方式見：

```text
docs/private-repo-access.md
```

## 一鍵執行

clone 下來後，在 repo 內執行：

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

## 驗證

安裝後先重啟 Hermes container/gateway，然後執行完整驗證：

```bash
bash scripts/verify-line.sh
```

會檢查：

- LINE env 是否存在。
- adapter.py 是否可編譯。
- 本機 health endpoint。
- 公開 health endpoint。

若只想在安裝過程中檢查 env 與 adapter 語法，可用：

```bash
bash scripts/verify-line.sh --skip-health
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
- 不要 commit 客戶 token、secret、password、API key。
- 若曾把 secret 貼到聊天或 repo，請立刻旋轉。
- private repo clone 用的 PAT 建議短效、只給 Contents Read-only。
- clone 完若 remote URL 帶 token，請改回乾淨 URL：

```bash
git remote set-url origin https://github.com/jimmyhsu1010/hostinger_line_implementation.git
```

- 修改 `/opt/hermes/plugins/platforms/line/adapter.py` 前 script 會自動備份。

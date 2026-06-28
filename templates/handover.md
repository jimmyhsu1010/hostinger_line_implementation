# LINE 小幫手交付說明

此環境是透過 Hostinger 一鍵部署 Hermes Agent 後，串接客戶自己的 LINE Official Account。

## 重要網址

WebUI：

```text
https://<your-hostinger-domain>/
```

LINE webhook：

```text
https://<your-hostinger-domain>/line/webhook
```

LINE health check：

```text
https://<your-hostinger-domain>/line/webhook/health
```

## 客戶資料位置

Hermes 預設資料目錄：

```text
/opt/data
```

Hostinger compose 通常對應：

```text
./data:/opt/data
```

請不要刪除：

- `/opt/data/config.yaml`
- `/opt/data/.env`
- `/opt/data/state.db`
- `/opt/data/sessions/`
- `/opt/data/logs/`

客戶可自行建立：

- `/opt/data/docs/`
- `/opt/data/knowledge/`
- `/opt/data/uploads/`

## LINE Developers 設定

Webhook URL：

```text
https://<your-hostinger-domain>/line/webhook
```

並確認：

- Use webhook: enabled
- Channel access token 已填入 `.env`
- Channel secret 已填入 `.env`

## 常用維護

重啟 container：

```bash
docker restart <container_name>
```

查看 logs：

```bash
docker logs --tail 200 <container_name>
```

檢查 LINE health：

```bash
curl -fsS https://<your-hostinger-domain>/line/webhook/health
```

## 安全提醒

- 不要公開 `.env`。
- 不要把 LINE token / secret 貼到聊天或 GitHub。
- 若 token 外洩，請到 LINE Developers 重新發行。

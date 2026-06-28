# Private GitHub repo access

This repo is private. Public raw URLs like this will NOT work unless the repo is made public or curl is authenticated:

```bash
curl -fsSL https://raw.githubusercontent.com/jimmyhsu1010/hostinger_line_implementation/main/scripts/bootstrap.sh | bash
```

Use one of these access methods instead.

## Recommended for quick client installs: temporary fine-grained PAT

1. Create a fine-grained GitHub token with access only to this repo.
2. Give it only:
   - Metadata: Read-only
   - Contents: Read-only
3. Set short expiration, e.g. 7 days.
4. On the customer Hostinger VPS/container environment, clone with the token without saving it in shell history:

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

After the install succeeds, revoke the token from GitHub if it was created only for this deployment.

## Alternative: SSH deploy key

For repeated deployments, add a read-only deploy key to the repo:

1. Generate an SSH key on the deployment machine.
2. Add the public key at GitHub repo Settings → Deploy keys.
3. Keep it read-only unless push access is intentionally required.
4. Clone with SSH:

```bash
cd /opt/data
git clone git@github.com:jimmyhsu1010/hostinger_line_implementation.git
cd hostinger_line_implementation
bash scripts/one-click-install.sh
```

## Alternative: download ZIP after login

If SSH/token setup is inconvenient, log in to GitHub in a browser, download the repo ZIP, upload it to the VPS, unzip it, then run:

```bash
cd /opt/data/hostinger_line_implementation
bash scripts/one-click-install.sh
```

## Important security notes

- Do not commit `.env`.
- Do not paste customer LINE secrets into GitHub.
- Do not leave PATs embedded in `git remote -v`.
- After cloning with a token, always reset origin to the clean URL:

```bash
git remote set-url origin https://github.com/jimmyhsu1010/hostinger_line_implementation.git
```

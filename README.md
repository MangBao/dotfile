# dotfiles — môi trường Claude Code trên Windows

## Máy hiện tại (đã setup xong): chụp config vào repo

```powershell
cd D:\fumirai-dev\dotfiles
powershell -ExecutionPolicy Bypass -File .\export.ps1
```

Script sẽ copy `~\.claude\settings.json`, hooks, danh sách marketplace plugin,
PowerShell profile và theme Oh My Posh vào repo. Đường dẫn home được thay bằng token
`{{HOME}}`, nên dùng được trên máy có username khác.
`claude/CLAUDE.md` trong repo là bản gốc: export không ghi đè trừ khi chạy với `-Force`.

Đọc lại `claude/settings.json` trước khi commit. Script sẽ dừng nếu thấy thứ giống secret.

## Máy mới

```powershell
git clone <repo-private-cua-ban> D:\fumirai-dev\dotfiles
cd D:\fumirai-dev\dotfiles
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Sau đó đóng và mở lại terminal, chạy `claude` để đăng nhập, rồi `/doctor`.
Nếu có bước nào lỗi, cuối output sẽ có mục "Needs manual follow-up".

Tùy chọn: `-SkipApps`, `-SkipPlugins`, `-SkipProfile`.
Script chạy lại bao nhiêu lần cũng được: bước nào đã xong thì bỏ qua.
File cũ bị thay được backup vào `~\.claude\backup-<thời gian>\`.

## Script cài những gì

| Bước | Nội dung |
|---|---|
| Apps | Git (machine scope, có Git Bash), uv, Node LTS, Oh My Posh |
| PATH | Thêm `C:\Program Files\Git\bin` (cho `sh` trong hook) |
| Python | `uv python install 3.12`, `graphifyy[mcp,pdf,sql]` |
| Claude Code | Native installer, `CLAUDE.md`, `settings.json`, hooks |
| Plugins | Add marketplace + install các plugin đang bật |
| Profile | PowerShell profile + theme Oh My Posh |

## Dùng graphify cho một project

Copy nội dung `templates/project-CLAUDE.md` vào `CLAUDE.md` ở gốc project, rồi:

```powershell
graphify extract . --code-only
graphify cluster-only . --no-label
```

## Không bao giờ commit

`.credentials.json`, `settings.local.json`, `.env*` (đã có trong `.gitignore`).

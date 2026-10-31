# Windows PowerShell 5.1 / PowerShell 7 용. Claude Code 운영 정책(CLAUDE.md), 에이전트, 스킬, 훅을 사용자 전역(~/.claude)에 설치한다. 프로젝트와 무관하다.
# 실행: powershell -ExecutionPolicy Bypass -File scripts/install-claude-global.ps1
# 이 파일은 한글 문자열 때문에 UTF-8 BOM 으로 저장돼 있다(Windows PowerShell 5.1 이 BOM 없는 UTF-8 을 ANSI 로 읽는다).
$ErrorActionPreference = "Stop"

$RepoDir    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ClaudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
$Stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir  = Join-Path $ClaudeHome "backups\claude-global-$Stamp"   # 스킬·에이전트 폴더 밖(안에 두면 스킬로 인식됨)
$Utf8NoBom  = New-Object System.Text.UTF8Encoding($false)

function Backup-Item($Path) {
  if (Test-Path $Path) {
    $rel = $Path.Substring($ClaudeHome.Length).TrimStart('\', '/')
    $dst = Join-Path $BackupDir $rel
    New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
    Copy-Item -Recurse -Force $Path $dst
  }
}
function To-Slash($p) { return ($p -replace '\\', '/') }   # claudeMdExcludes 와 훅 명령은 슬래시 경로로

Write-Host "설치 대상: $ClaudeHome"
foreach ($d in @("agents", "skills", "hooks")) { New-Item -ItemType Directory -Force (Join-Path $ClaudeHome $d) | Out-Null }

# 1. 운영 정책 (저장소 CLAUDE.md) → ~/.claude/CLAUDE.md 의 마커 블록으로 병합 (사용자의 다른 내용은 보존, 멱등)
$Umd    = Join-Path $ClaudeHome "CLAUDE.md"
$policy = [System.IO.File]::ReadAllText((Join-Path $RepoDir "CLAUDE.md"), [System.Text.Encoding]::UTF8).Trim()
$Block  = "<!-- claude-routing:policy:start -->`n" + $policy + "`n<!-- claude-routing:policy:end -->"
Backup-Item $Umd
$cur = if (Test-Path $Umd) { [System.IO.File]::ReadAllText($Umd, [System.Text.Encoding]::UTF8) } else { "" }
if ($cur -match 'claude-routing:policy:start') {
  $cur = [regex]::Replace($cur, '(?s)<!-- claude-routing:policy:start -->.*?<!-- claude-routing:policy:end -->', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $Block })
} else {
  if ($cur.Length -gt 0 -and -not $cur.EndsWith("`n")) { $cur += "`n" }
  if ($cur.Length -gt 0) { $cur += "`n" }
  $cur += $Block + "`n"
}
[System.IO.File]::WriteAllText($Umd, $cur, $Utf8NoBom)
Write-Host "1/5 ~/.claude/CLAUDE.md: 운영 정책 블록"

# 2. 에이전트
Get-ChildItem (Join-Path $RepoDir ".claude\agents\*.md") | ForEach-Object {
  $dst = Join-Path $ClaudeHome "agents\$($_.Name)"
  Backup-Item $dst
  Copy-Item -Force $_.FullName $dst
}
Write-Host "2/5 agents"

# 3. 스킬 (전역 사본의 global-install 은 이 저장소의 절대 경로를 가리키게 바꾼다)
Get-ChildItem -Directory (Join-Path $RepoDir ".claude\skills") | ForEach-Object {
  $dst = Join-Path $ClaudeHome "skills\$($_.Name)"
  Backup-Item $dst
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
  Copy-Item -Recurse -Force $_.FullName $dst
}
$GI = Join-Path $ClaudeHome "skills\global-install\SKILL.md"
if (Test-Path $GI) {
  $txt = [System.IO.File]::ReadAllText($GI, [System.Text.Encoding]::UTF8)
  $txt = $txt.Replace("scripts/install-claude-global", (To-Slash $RepoDir) + "/scripts/install-claude-global")
  [System.IO.File]::WriteAllText($GI, $txt, $Utf8NoBom)
}
Write-Host "3/5 skills"

# 4. 훅 스크립트 (Claude Code 는 Windows 에서도 Git Bash 로 command 훅을 실행한다)
$HookDst = Join-Path $ClaudeHome "hooks\require-opus.sh"
Backup-Item $HookDst
Copy-Item -Force (Join-Path $RepoDir ".claude\hooks\require-opus.sh") $HookDst
Write-Host "4/5 hooks/require-opus.sh"

# 5. settings.json 병합 (PowerShell 5.1 호환: -AsHashtable 사용 안 함, BOM 없이 저장)
$Settings = Join-Path $ClaudeHome "settings.json"
$RuleAbs  = To-Slash (Join-Path $RepoDir "CLAUDE.md")   # 이 저장소 안에서 정책이 두 번 로드되지 않게 제외
$HookCmd  = 'bash "' + (To-Slash $HookDst) + '"'
Backup-Item $Settings
$data = [PSCustomObject]@{}
$skipSettings = $false
if (Test-Path $Settings) {
  $raw = [System.IO.File]::ReadAllText($Settings, [System.Text.Encoding]::UTF8)
  if ($raw -and $raw.Trim()) {
    try { $data = $raw | ConvertFrom-Json }
    catch { $skipSettings = $true; Write-Host "5/5 건너뜀: $Settings 가 순수 JSON 이 아니다. 아래 항목을 직접 추가하라." }
  }
}
if (-not $skipSettings) {
  if (-not ($data.PSObject.Properties.Name -contains "env")) { $data | Add-Member -NotePropertyName env -NotePropertyValue ([PSCustomObject]@{}) }
  if ($data.env.PSObject.Properties.Name -contains "CLAUDE_CODE_SUBAGENT_MODEL") {
    if ($data.env.CLAUDE_CODE_SUBAGENT_MODEL -ne "opus") { Write-Host "  기존 CLAUDE_CODE_SUBAGENT_MODEL=$($data.env.CLAUDE_CODE_SUBAGENT_MODEL) 를 opus 로 덮어쓴다(백업 있음)." }
    $data.env.CLAUDE_CODE_SUBAGENT_MODEL = "opus"
  } else { $data.env | Add-Member -NotePropertyName CLAUDE_CODE_SUBAGENT_MODEL -NotePropertyValue "opus" }
  if (-not ($data.env.PSObject.Properties.Name -contains "CLAUDE_CODE_FORK_SUBAGENT")) { $data.env | Add-Member -NotePropertyName CLAUDE_CODE_FORK_SUBAGENT -NotePropertyValue "0" }

  if (-not ($data.PSObject.Properties.Name -contains "hooks")) { $data | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) }
  if (-not ($data.hooks.PSObject.Properties.Name -contains "PreToolUse")) { $data.hooks | Add-Member -NotePropertyName PreToolUse -NotePropertyValue @() }
  $pre = @($data.hooks.PreToolUse)
  $present = $false
  foreach ($g in $pre) { foreach ($h in @($g.hooks)) { if ($h -and $h.command -and ($h.command -like "*require-opus.sh*")) { $present = $true } } }
  if (-not $present) {
    $entry = [PSCustomObject]@{ matcher = "Agent"; hooks = @([PSCustomObject]@{ type = "command"; command = $HookCmd; timeout = 10; statusMessage = "서브에이전트 모델 확인 (Opus 고정)" }) }
    $pre += $entry
  }
  $data.hooks.PreToolUse = $pre

  if (-not ($data.PSObject.Properties.Name -contains "claudeMdExcludes")) { $data | Add-Member -NotePropertyName claudeMdExcludes -NotePropertyValue @() }
  $ex = @($data.claudeMdExcludes)
  if ($ex -notcontains $RuleAbs) { $ex += $RuleAbs }
  $data.claudeMdExcludes = $ex

  $json = $data | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Settings, $json + "`n", $Utf8NoBom)
  Write-Host "5/5 settings.json: env.CLAUDE_CODE_SUBAGENT_MODEL=opus, env.CLAUDE_CODE_FORK_SUBAGENT=0, PreToolUse 훅, claudeMdExcludes += $RuleAbs"
  if ($data.env.PSObject.Properties.Name -contains "CLAUDE_CODE_EFFORT_LEVEL") { Write-Host "경고: settings.json env 에 CLAUDE_CODE_EFFORT_LEVEL 이 있다. 에이전트별 effort 가 모두 무시되므로 지우기를 권한다." }
} else {
  Write-Host ('  "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "opus", "CLAUDE_CODE_FORK_SUBAGENT": "0" },')
  Write-Host ('  "hooks": { "PreToolUse": [ { "matcher": "Agent", "hooks": [ { "type": "command", "command": "' + $HookCmd.Replace('"', '\"') + '", "timeout": 10 } ] } ] },')
  Write-Host ('  "claudeMdExcludes": [ "' + $RuleAbs + '" ]')
}

if ($env:CLAUDE_CODE_EFFORT_LEVEL) { Write-Host "경고: 환경변수 CLAUDE_CODE_EFFORT_LEVEL=$($env:CLAUDE_CODE_EFFORT_LEVEL) 이 설정돼 있다. 에이전트별 effort 가 모두 무시되므로 해제를 권한다." }

Write-Host ""
Write-Host "완료. 백업: $BackupDir (변경된 파일이 있을 때만 생성)"
Write-Host "새 세션에서 확인: /context (~/.claude/CLAUDE.md 로드), claude plugin validate ~/.claude/agents, /tasks (위임 후 Opus + effort)"
Write-Host "저장소의 정책이나 스킬을 고치거나 pull 한 뒤에는 이 스크립트를 다시 실행한다."

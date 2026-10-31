# Windows PowerShell 용. 이 저장소의 Claude Code 운영 정책, 에이전트, 스킬을 사용자 전역(~/.claude)에 설치한다.
# 실행: powershell -ExecutionPolicy Bypass -File scripts/install-claude-global.ps1
$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ClaudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Backup-Item($Path) {
  if (Test-Path $Path) {
    Copy-Item -Recurse -Force $Path "$Path.bak-$Stamp"
    Write-Host "  백업: $Path -> $Path.bak-$Stamp"
  }
}

Write-Host "설치 대상: $ClaudeHome"
foreach ($d in @("rules", "agents", "skills")) { New-Item -ItemType Directory -Force (Join-Path $ClaudeHome $d) | Out-Null }

# 1. 운영 정책
$RuleDst = Join-Path $ClaudeHome "rules\routing.md"
Backup-Item $RuleDst
Copy-Item -Force (Join-Path $RepoDir ".claude\rules\routing.md") $RuleDst
Write-Host "1/4 rules/routing.md 설치"

# 2. 에이전트
Get-ChildItem (Join-Path $RepoDir ".claude\agents\*.md") | ForEach-Object {
  $dst = Join-Path $ClaudeHome "agents\$($_.Name)"
  Backup-Item $dst
  Copy-Item -Force $_.FullName $dst
}
Write-Host "2/4 agents 설치"

# 3. 스킬
Get-ChildItem -Directory (Join-Path $RepoDir ".claude\skills") | ForEach-Object {
  $dst = Join-Path $ClaudeHome "skills\$($_.Name)"
  Backup-Item $dst
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
  Copy-Item -Recurse -Force $_.FullName $dst
}
Write-Host "3/4 skills 설치"

# 4. settings.json 병합
$Settings = Join-Path $ClaudeHome "settings.json"
$RuleAbs = (Join-Path $RepoDir ".claude\rules\routing.md")
Backup-Item $Settings
$data = @{}
if (Test-Path $Settings) {
  $raw = Get-Content -Raw $Settings
  if ($raw.Trim()) { $data = $raw | ConvertFrom-Json -AsHashtable }
}
if (-not $data.ContainsKey("env")) { $data["env"] = @{} }
if (-not $data["env"].ContainsKey("CLAUDE_CODE_SUBAGENT_MODEL")) { $data["env"]["CLAUDE_CODE_SUBAGENT_MODEL"] = "opus" }
if (-not $data.ContainsKey("claudeMdExcludes")) { $data["claudeMdExcludes"] = @() }
if ($data["claudeMdExcludes"] -notcontains $RuleAbs) { $data["claudeMdExcludes"] = @($data["claudeMdExcludes"]) + $RuleAbs }
$data | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $Settings
Write-Host "4/4 settings.json 병합: env.CLAUDE_CODE_SUBAGENT_MODEL=opus, claudeMdExcludes += $RuleAbs"

if ($env:CLAUDE_CODE_EFFORT_LEVEL) {
  Write-Host "경고: CLAUDE_CODE_EFFORT_LEVEL=$($env:CLAUDE_CODE_EFFORT_LEVEL) 이 설정돼 있다. 에이전트별 effort가 모두 무시되므로 해제를 권장한다."
}

Write-Host ""
Write-Host "완료. 새 세션에서 확인: /context (routing.md 로드), /agents (worker, verifier, researcher, designer, Explore), /tasks (위임 후 Opus + effort)"

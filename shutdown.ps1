# shutdown_tasks.ps1
# 指定ディレクトリ内の指示書ファイルを処理し、シャットダウンを実行するスクリプト

# 設定
$TaskDir = "shutdown_tasks"  # 指示書ファイルが置かれているディレクトリ（適宜変更）
$LogFile = Join-Path $TaskDir "shutdown_task_log.txt"
$ArchiveDir = Join-Path $TaskDir "archive"
if (-not (Test-Path -Path $ArchiveDir)) {
    New-Item -Path $ArchiveDir -ItemType Directory -Force | Out-Null
    Add-Content -Path $LogFile -Value "[INFO] Archiveディレクトリを作成しました: $ArchiveDir"
}

# 今日の曜日を数値に変換（Monday=1, Tuesday=2, ... Sunday=7）
$today = (Get-Date).DayOfWeek
switch ($today) {
    "Monday"    { $todayNum = "1" }
    "Tuesday"   { $todayNum = "2" }
    "Wednesday" { $todayNum = "3" }
    "Thursday"  { $todayNum = "4" }
    "Friday"    { $todayNum = "5" }
    "Saturday"  { $todayNum = "6" }
    "Sunday"    { $todayNum = "7" }
    default     { $todayNum = "" }
}

if ([string]::IsNullOrEmpty($todayNum)) {
    Add-Content -Path $LogFile -Value "[ERROR] 今日の曜日が取得できませんでした。"
    exit 1
}

# 優先度別にファイルを取得 (h_ が優先、次に n_)
# 指定ディレクトリから h_* と n_* のファイルを配列として取得
$highPriorityFiles = @(Get-ChildItem -Path $TaskDir -Filter "h_*" -File -ErrorAction SilentlyContinue)
$normalFiles     = @(Get-ChildItem -Path $TaskDir -Filter "n_*" -File -ErrorAction SilentlyContinue)

# ------------------------------
# 優先度の高いファイル (h_*) の処理
# ------------------------------
$highPriorityFiles = @(Get-ChildItem -Path $TaskDir -Filter "h_*" -File -ErrorAction SilentlyContinue)
foreach ($file in $highPriorityFiles) {
    $filename = $file.Name
    # ファイル名を "_" で分割。最低4パーツ必要（priority_count_days_identifier）
    $parts = $filename -split "_"
    if ($parts.Length -lt 4) {
        Add-Content -Path $LogFile -Value "[ERROR] $filename : ファイル名の形式が不正です。"
        Write-Host "[ERROR] $filename : ファイル名の形式が不正です。"
        exit 1
    }
    $priority = $parts[0]
    $count = $parts[1]
    $days = $parts[2]
    $id = ($parts[3..($parts.Length - 1)] -join "_")
    
    # 今日の曜日 ($todayNum) が指定された曜日($days)に含まれているかチェック
    if ($days -notlike "*$todayNum*") {
        Add-Content -Path $LogFile -Value "[SKIP] $filename : 本日の曜日($todayNum)は対象外です。"
        continue
    }
    
    # 指示書ファイルの1行目から実行コマンドを取得
    try {
        $commandLine = Get-Content -Path $file.FullName -ErrorAction Stop | Select-Object -First 1
    }
    catch {
        Add-Content -Path $LogFile -Value "[ERROR] $filename : ファイルの読み込みに失敗しました。Error: $_"
        Write-Host "[ERROR] $filename : ファイルの読み込みに失敗しました。Error: $_"
        exit 1
    }
    
    if ([string]::IsNullOrWhiteSpace($commandLine)) {
        Add-Content -Path $LogFile -Value "[ERROR] $filename : コマンドラインが空です。"
        Write-Host "[ERROR] $filename : コマンドラインが空です。"
        exit 1
    }
    
    Add-Content -Path $LogFile -Value "[INFO] $filename : 実行コマンド -> $commandLine"
    
    # コマンドの実行
    try {
        Invoke-Expression $commandLine
        if ($LASTEXITCODE -ne 0) {
            throw "コマンドの終了コードが $LASTEXITCODE でした。"
        }
    }
    catch {
        Add-Content -Path $LogFile -Value "[ERROR] $filename : コマンド実行に失敗しました。Error: $_"
        Write-Host "[ERROR] $filename : コマンド実行に失敗しました。Error: $_"
        exit 1
    }
    
    # 残数の更新。count が "p" の場合は無限実行とみなす
    if ($count -ne "p") {
        if ([int]::TryParse($count, [ref]$null)) {
            $newCount = [int]$count - 1
            if ($newCount -le 0) {
                try {
                    # 新しいファイル名を「priority_0_days_identifier」に変更
                    $newFileName = "$priority" + "_" + "0" + "_" + "$days" + "_" + "$id"
                    Rename-Item -Path $file.FullName -NewName $newFileName -ErrorAction Stop
                    # 移動先のファイルパスを作成（Archive フォルダ内に元のファイル名で移動）
                    $destination = Join-Path $ArchiveDir $newFileName
                    $newFilepath = Join-Path $TaskDir $newFileName
                    Move-Item -Path $newFilepath -Destination $destination -ErrorAction Stop
                    Add-Content -Path $LogFile -Value "[INFO] $filename : カウントが0になったため、ファイルをアーカイブに移動しました。"
                }
                catch {
                    Add-Content -Path $LogFile -Value "[ERROR] $filename : ファイルの移動に失敗しました。Error: $_"
                }
            }
            else {
                $newFileName = "$priority" + "_" + "$newCount" + "_" + "$days" + "_" + "$id"
                try {
                    Rename-Item -Path $file.FullName -NewName $newFileName -ErrorAction Stop
                    Add-Content -Path $LogFile -Value "[INFO] $filename : カウントを $newCount に更新。新ファイル名: $newFileName"
                }
                catch {
                    Add-Content -Path $LogFile -Value "[ERROR] $filename : ファイル名の変更に失敗しました。Error: $_"
                }
            }
        }
        else {
            Add-Content -Path $LogFile -Value "[ERROR] $filename : カウント部分が数値として認識できません。"
        }
    }
    else {
        Add-Content -Path $LogFile -Value "[INFO] $filename : カウントは無限 (p) として設定されています。"
    }
}

# 優先度の高いファイル処理終了時に標準出力へ通知
Write-Host "High priority processing completed."

# ------------------------------
# 通常優先度のファイル (n_*) の処理
# ------------------------------
$normalFiles = @(Get-ChildItem -Path $TaskDir -Filter "n_*" -File -ErrorAction SilentlyContinue)
foreach ($file in $normalFiles) {
    $filename = $file.Name
    $parts = $filename -split "_"
    if ($parts.Length -lt 4) {
        Add-Content -Path $LogFile -Value "[SKIP] $filename : ファイル名の形式が不正です。"
        continue
    }
    $priority = $parts[0]
    $count = $parts[1]
    $days = $parts[2]
    $id = ($parts[3..($parts.Length - 1)] -join "_")
    
    if ($days -notlike "*$todayNum*") {
        Add-Content -Path $LogFile -Value "[SKIP] $filename : 本日の曜日($todayNum)は対象外です。"
        continue
    }
    
    try {
        $commandLine = Get-Content -Path $file.FullName -ErrorAction Stop | Select-Object -First 1
    }
    catch {
        Add-Content -Path $LogFile -Value "[ERROR] $filename : ファイルの読み込みに失敗しました。Error: $_"
        continue
    }
    
    if ([string]::IsNullOrWhiteSpace($commandLine)) {
        Add-Content -Path $LogFile -Value "[ERROR] $filename : コマンドラインが空です。"
        continue
    }
    
    Add-Content -Path $LogFile -Value "[INFO] $filename : 実行コマンド -> $commandLine"
    
    try {
        Invoke-Expression $commandLine
        if ($LASTEXITCODE -ne 0) {
            throw "コマンドの終了コードが $LASTEXITCODE でした。"
        }
    }
    catch {
        Add-Content -Path $LogFile -Value "[ERROR] $filename : コマンド実行に失敗しました。Error: $_"
        continue
    }
    
    if ($count -ne "p") {
        if ([int]::TryParse($count, [ref]$null)) {
            $newCount = [int]$count - 1
            if ($newCount -le 0) {
                try {
                    # 新しいファイル名を「priority_0_days_identifier」に変更
                    $newFileName = "$priority" + "_" + "0" + "_" + "$days" + "_" + "$id"
                    Rename-Item -Path $file.FullName -NewName $newFileName -ErrorAction Stop
                    # 移動先のファイルパスを作成（Archive フォルダ内に元のファイル名で移動）
                    $destination = Join-Path $ArchiveDir $newFileName
                    $newFilepath = Join-Path $TaskDir $newFileName
                    Move-Item -Path $newFilepath -Destination $destination -ErrorAction Stop
                    Add-Content -Path $LogFile -Value "[INFO] $filename : カウントが0になったため、ファイルをアーカイブに移動しました。"
                }
                catch {
                    Add-Content -Path $LogFile -Value "[ERROR] $filename : ファイルの移動に失敗しました。Error: $_"
                }
            }
            else {
                $newFileName = "$priority" + "_" + "$newCount" + "_" + "$days" + "_" + "$id"
                try {
                    Rename-Item -Path $file.FullName -NewName $newFileName -ErrorAction Stop
                    Add-Content -Path $LogFile -Value "[INFO] $filename : カウントを $newCount に更新。新ファイル名: $newFileName"
                }
                catch {
                    Add-Content -Path $LogFile -Value "[ERROR] $filename : ファイル名の変更に失敗しました。Error: $_"
                }
            }
        }
        else {
            Add-Content -Path $LogFile -Value "[ERROR] $filename : カウント部分が数値として認識できません。"
        }
    }
    else {
        Add-Content -Path $LogFile -Value "[INFO] $filename : カウントは無限 (p) として設定されています。"
    }
}

# シャットダウンの実行
Add-Content -Path $LogFile -Value "[INFO] シャットダウンを10秒後に開始します。"
$today_date=(Get-Date).DateTime
Add-Content -Path $LogFile -Value "-------------------------------end:$today_date"
# shutdown.exe を使ってシャットダウン（10秒後）
shutdown.exe /s /t 10

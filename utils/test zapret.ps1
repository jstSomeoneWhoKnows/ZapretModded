try {
	$ErrorActionPreference = 'Continue'  # чтобы не останавливаться на каждой ошибке вывода
	[Console]::OutputEncoding = [Text.Encoding]::UTF8
	$PSDefaultParameterValues['*:Encoding'] = 'utf8'
	$hasErrors = $false

	$rootDir = Split-Path $PSScriptRoot
	$listsDir = Join-Path $rootDir "lists"
	$utilsDir = Join-Path $rootDir "utils"
	$resultsDir = Join-Path $utilsDir "test results"
	if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir | Out-Null }

	# Определяем функции заранее
	function Get-IpsetStatus {
		$listFile = Join-Path $listsDir "ipset-all.txt"
		if (-not (Test-Path $listFile)) { return "none" }
		$lineCount = (Get-Content $listFile | Measure-Object -Line).Lines
		if ($lineCount -eq 0) { return "any" }
		$hasDummy = Get-Content $listFile | Select-String -Pattern "203\.0\.113\.113/32" -Quiet
		if ($hasDummy) { return "none" } else { return "loaded" }
	}

	function Set-IpsetMode {
		param([string]$mode)
		$listFile = Join-Path $listsDir "ipset-all.txt"
		$backupFile = Join-Path $listsDir "ipset-all.test-backup.txt"
		if ($mode -eq "any") {
			# Всегда создаём резервную копию текущего файла (даже если его нет)
			if (Test-Path $listFile) {
				Copy-Item $listFile $backupFile -Force
			} else {
				# Если файла нет, создаём пустую резервную копию
				"" | Out-File $backupFile -Encoding UTF8
			}
			# Делаем файл пустым
			"" | Out-File $listFile -Encoding UTF8
		} elseif ($mode -eq "restore") {
			if (Test-Path $backupFile) {
				Move-Item $backupFile $listFile -Force
			}
		}
	}

	# Обработчик прерывания для восстановления ipset
	trap {
		Write-Host "[ОШИБКА] Скрипт прерван. Восстанавливаю ipset..." -ForegroundColor Red
		if ($originalIpsetStatus -and $originalIpsetStatus -ne "any") {
			Set-IpsetMode -mode "restore"
		}
		Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
		break
	}

	function New-OrderedDict { New-Object System.Collections.Specialized.OrderedDictionary }
	function Add-OrSet {
		param($dict, $key, $val)
		if ($dict.Contains($key)) { $dict[$key] = $val } else { $dict.Add($key, $val) }
	}

	# Преобразует исходное значение цели в структурированную цель (поддерживает PING:ip для целей только с пингом)
	function Convert-Target {
		param(
			[string]$Name,
			[string]$Value
		)

		if ($Value -like "PING:*") {
			$ping = $Value -replace '^PING:\s*', ''
			$url = $null
			$pingTarget = $ping
		} else {
			$url = $Value
			$pingTarget = $url -replace "^https?://", "" -replace "/.*$", ""
		}

		return (New-Object PSObject -Property @{
			Name       = $Name
			Url        = $url
			PingTarget = $pingTarget
		})
	}

	# Настройки проверки DPI по умолчанию (переопределяются через переменные окружения MONITOR_*, как в monitor.ps1)
	$dpiTimeoutSeconds = 5
	$dpiRangeBytes = 262144
	$dpiWarnMinKB = 14
	$dpiWarnMaxKB = 22
	$dpiMaxParallel = 8
	$dpiCustomUrl = $env:MONITOR_URL
	if ($env:MONITOR_TIMEOUT) { [int]$dpiTimeoutSeconds = $env:MONITOR_TIMEOUT }
	if ($env:MONITOR_RANGE) { [int]$dpiRangeBytes = $env:MONITOR_RANGE }
	if ($env:MONITOR_WARN_MINKB) { [int]$dpiWarnMinKB = $env:MONITOR_WARN_MINKB }
	if ($env:MONITOR_WARN_MAXKB) { [int]$dpiWarnMaxKB = $env:MONITOR_WARN_MAXKB }
	if ($env:MONITOR_MAX_PARALLEL) { [int]$dpiMaxParallel = $env:MONITOR_MAX_PARALLEL }

	function Get-DpiSuite {
		# Набор тестов взят из https://github.com/hyperion-cs/dpi-checkers (лицензия Apache-2.0)
		# Оригинальные авторские права сохраняются за репозиторием dpi-checkers
		$url = "https://hyperion-cs.github.io/dpi-checkers/ru/tcp-16-20/suite.json"

		try {
			(Invoke-RestMethod -Uri $url -TimeoutSec $dpiTimeoutSeconds) |
				Select-Object `
					@{n='Id';       e={$_.id}},
					@{n='Provider'; e={$_.provider}},
					@{n='Url';      e={$_.url}},
					@{n='Times';    e={$_.times}}
		}
		catch {
			Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Не удалось загрузить набор DPI-тестов." -ForegroundColor Yellow
			@()
		}
	}

	function Build-DpiTargets {
		param(
			[string]$CustomUrl
		)

		$suite = Get-DpiSuite
		$targets = @()

		if ($CustomUrl) {
			$targets += @{ Id = "CUSTOM"; Provider = "Custom"; Url = $CustomUrl }
		} else {
			foreach ($entry in $suite) {
				$repeat = $entry.Times
				if (-not $repeat -or $repeat -lt 1) { $repeat = 1 }
				for ($i = 0; $i -lt $repeat; $i++) {
					$suffix = ""
					if ($repeat -gt 1) { $suffix = "@$i" }
					$targets += @{ Id = "$($entry.Id)$suffix"; Provider = $entry.Provider; Url = $entry.Url }
				}
			}
		}

		return $targets
	}

	function Invoke-DpiSuite {
		param(
			[array]$Targets,
			[int]$TimeoutSeconds,
			[int]$RangeBytes,
			[int]$WarnMinKB,
			[int]$WarnMaxKB,
			[int]$MaxParallel
		)

		$tests = @(
			@{ Label = "HTTP";   Args = @("--http1.1") },
			@{ Label = "TLS1.2"; Args = @("--tlsv1.2", "--tls-max", "1.2") },
			@{ Label = "TLS1.3"; Args = @("--tlsv1.3", "--tls-max", "1.3") }
		)

		$rangeSpec = "0-$($RangeBytes - 1)"
		$warnDetected = $false

		Write-Host "[ИНФО] Целей: $($Targets.Count) (пользовательский URL заменяет набор). Диапазон: $rangeSpec байт; Таймаут: $TimeoutSeconds с; Окно предупреждения: $WarnMinKB-$WarnMaxKB КБ" -ForegroundColor Cyan
		Write-Host "[ИНФО] Запуск проверок DPI TCP 16-20 (параллельно: $MaxParallel)..." -ForegroundColor DarkGray

		$runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxParallel)
		$runspacePool.Open()

		$scriptBlock = {
			param($target, $tests, $rangeSpec, $TimeoutSeconds, $WarnMinKB, $WarnMaxKB)

			$warned = $false
			$lines = @()

			foreach ($test in $tests) {
				$curlArgs = @(
					"-L",
					"--range", $rangeSpec,
					"-m", $TimeoutSeconds,
					"-w", "%{http_code} %{size_download}",
					"-o", "NUL",
					"-s"
				) + $test.Args + $target.Url

				$output = & curl.exe @curlArgs 2>&1
				$exit = $LASTEXITCODE
				$text = ($output | Out-String).Trim()

				$code = "NA"
				$sizeBytes = 0

				if ($text -match '^(?<code>\d{3})\s+(?<size>\d+)$') {
					$code = $matches['code']
					$sizeBytes = [int64]$matches['size']
				} elseif (($exit -eq 35) -or ($text -match "not supported|does not support|protocol\s+'.+'\s+not\s+supported|protocol\s+.+\s+not\s+supported|unsupported protocol|TLS.not supported|Unrecognized option|Unknown option|unsupported option|unsupported feature|schannel|SSL")) {
					$code = "UNSUP"
				} elseif ($text) {
					$code = "ERR"
				}

				$sizeKB = [math]::Round($sizeBytes / 1024, 1)
				$status = "OK"
				$color = "Green"

				if ($code -eq "UNSUP") {
					$status = "UNSUPPORTED"
					$color = "Yellow"
				} elseif ($exit -ne 0 -or $code -eq "ERR" -or $code -eq "NA") {
					$status = "FAIL"
					$color = "Red"
				}

				if (($sizeKB -ge $WarnMinKB) -and ($sizeKB -le $WarnMaxKB) -and ($exit -ne 0)) {
					$status = "LIKELY_BLOCKED"
					$color = "Yellow"
					$warned = $true
				}

				$lines += [PSCustomObject]@{
					TargetId   = $target.Id
					Provider   = $target.Provider
					TestLabel  = $test.Label
					Code       = $code
					SizeBytes  = $sizeBytes
					SizeKB     = $sizeKB
					Status     = $status
					Color      = $color
					Warned     = $warned
				}
			}

			return [PSCustomObject]@{
				TargetId = $target.Id
				Provider = $target.Provider
				Lines    = $lines
				Warned   = $warned
			}
		}

		$runspaces = @()
		foreach ($target in $Targets) {
			$ps = [powershell]::Create().AddScript($scriptBlock)
			[void]$ps.AddArgument($target)
			[void]$ps.AddArgument($tests)
			[void]$ps.AddArgument($rangeSpec)
			[void]$ps.AddArgument($TimeoutSeconds)
			[void]$ps.AddArgument($WarnMinKB)
			[void]$ps.AddArgument($WarnMaxKB)
			$ps.RunspacePool = $runspacePool
			
			$runspaces += [PSCustomObject]@{
				Powershell = $ps
				Handle     = $ps.BeginInvoke()
			}
		}

		# Сбор результатов
		$results = @()
		foreach ($rs in $runspaces) {
			try {
				$waitMs = ([int]$TimeoutSeconds + 5) * 1000
				$handle = $rs.Handle
				if ($handle -and $handle.AsyncWaitHandle) {
					$completed = $handle.AsyncWaitHandle.WaitOne($waitMs)
					if (-not $completed) {
						Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Runspace для цели не завершился за $waitMs мс; останавливаем runspace..." -ForegroundColor Yellow
						try { $rs.Powershell.Stop() } catch {}
					}
				}
			} catch {
				# игнорируем ошибки ожидания
			}

			try {
				$result = $rs.Powershell.EndInvoke($rs.Handle)
				if ($result) { $results += $result }
			} catch {
		Write-Host "[WARN] EndInvoke ошибся в  runspace; считаем ошибкой..." -ForegroundColor Yellow
		$failedLine = [PSCustomObject]@{
			TargetId   = 'UNKNOWN'
			Provider   = 'UNKNOWN'
			TestLabel  = 'RUNSPACE'
			Code       = 'ERR'
			SizeBytes  = 0
			SizeKB     = 0
			Status     = 'FAIL'
			Color      = 'Red'
			Warned     = $false
		}
		$results += [PSCustomObject]@{ 
			TargetId = 'UNKNOWN'
			Provider = 'UNKNOWN'
			Lines    = @($failedLine)
			Warned   = $false 
		}
	}
			$rs.Powershell.Dispose()
		}
		$runspacePool.Close()
		$runspacePool.Dispose()

		# Вывод результатов
		foreach ($res in $results) {
			Write-Host "`n=== $($res.TargetId) [$($res.Provider)] ===" -ForegroundColor DarkCyan

			foreach ($line in $res.Lines) {
				$msg = "[{0}][{1}] код={2} размер={3} байт({4}КБ) статус={5}" -f $line.TargetId, $line.TestLabel, $line.Code, $line.SizeBytes, $line.SizeKB, $line.Status
				Write-Host $msg -ForegroundColor $line.Color
				if ($line.Status -eq "LIKELY_BLOCKED") {
					Write-Host "  Обнаружена заморозка 16-20 КБ; цензор, вероятно, обрезает эту стратегию." -ForegroundColor Yellow
				}
			}

			if (-not $res.Warned) {
				Write-Host "  Для этой цели заморозка 16-20 КБ не обнаружена." -ForegroundColor Green
			} else {
				$warnDetected = $true
			}
		}

		if ($warnDetected) {
			Write-Host ""
			Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Обнаружена возможная блокировка DPI TCP 16-20 на одной или нескольких целях. Попробуйте сменить стратегию/SNI/IP." -ForegroundColor Red
		} else {
			Write-Host ""
			Write-Host "[ОК] Заморозка 16-20 КБ не обнаружена ни на одной цели." -ForegroundColor Green
		}

		return $results
	}

	function Test-ZapretServiceConflict {
		return [bool](Get-Service -Name "zapret" -ErrorAction SilentlyContinue)
	}

	# Остановка winws
	function Stop-Zapret {
		Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force
	}

	# Захват/восстановление запущенных экземпляров winws для возврата пользовательского ipset/config
	function Get-WinwsSnapshot {
		try {
			return Get-CimInstance Win32_Process -Filter "Name='winws.exe'" -ErrorAction SilentlyContinue |
				Select-Object ProcessId, CommandLine, ExecutablePath
		} catch {
			return @()
		}
	}

	function Restore-WinwsSnapshot {
		param($snapshot)

		if (-not $snapshot -or $snapshot.Count -eq 0) { return }

		$current = @()
		try { $current = (Get-WinwsSnapshot).CommandLine } catch { $current = @() }

		Write-Host "[ИНФО] Восстанавливаю ранее запущенные экземпляры winws..." -ForegroundColor DarkGray
		foreach ($p in $snapshot) {
			if (-not $p.ExecutablePath) { continue }

			# Пропускаем, если идентичная командная строка уже активна
			if ($current -and $current -contains $p.CommandLine) { continue }

			$exe = $p.ExecutablePath
			$processArgs = ""
			if ($p.CommandLine) {
				$quotedExe = '"' + $exe + '"'
				if ($p.CommandLine.StartsWith($quotedExe)) {
					$processArgs = $p.CommandLine.Substring($quotedExe.Length).Trim()
				} elseif ($p.CommandLine.StartsWith($exe)) {
					$processArgs = $p.CommandLine.Substring($exe.Length).Trim()
				}
			}

			Start-Process -FilePath $exe -ArgumentList $processArgs -WorkingDirectory (Split-Path $exe -Parent) -WindowStyle Minimized | Out-Null
			Write-Host "  [DEBUG] WorkingDirectory: $rootDir" -ForegroundColor DarkGray
			Write-Host "  [DEBUG] Bat full path: $($file.FullName)" -ForegroundColor DarkGray
		}
	}

	# Выбор типа тестов верхнего уровня (стандартные или DPI-проверки)
	function Read-TestType {
		while ($true) {
			Write-Host ""
			Write-Host "Выберите тип тестов:" -ForegroundColor Cyan
			Write-Host "  [1] Стандартные тесты (HTTP/пинг)" -ForegroundColor Gray
			Write-Host "  [2] DPI-проверки (заморозка TCP 16-20)" -ForegroundColor Gray
			$choice = Read-Host "Введите 1 или 2"
			switch ($choice) {
				'1' { return 'standard' }
				'2' { return 'dpi' }
				default { Write-Host "Неверный ввод. Пожалуйста, попробуйте снова." -ForegroundColor Yellow }
			}
		}
	}

	# Выбор режима запуска тестов: все конфигурации или выборочный набор
	function Read-ModeSelection {
		while ($true) {
			Write-Host ""
			Write-Host "Выберите режим запуска тестов:" -ForegroundColor Cyan
			Write-Host "  [1] Все конфигурации" -ForegroundColor Gray
			Write-Host "  [2] Выбранные конфигурации" -ForegroundColor Gray
			$choice = Read-Host "Введите 1 или 2"
			switch ($choice) {
				'1' { return 'all' }
				'2' { return 'select' }
				default { Write-Host "Неверный ввод. Пожалуйста, попробуйте снова." -ForegroundColor Yellow }
			}
		}
	}

	function Read-ConfigSelection {
		param([array]$allFiles)

		while ($true) {
			Write-Host ""
			Write-Host "Доступные конфигурации:" -ForegroundColor Cyan
			for ($i = 0; $i -lt $allFiles.Count; $i++) {
				$idx = $i + 1
				Write-Host "  [$idx] $($allFiles[$i].Name)" -ForegroundColor Gray
			}

			$selectionInput = Read-Host "Введите номера через запятую (например, 1,3,5) или '0' для запуска всех"
			$trimmed = $selectionInput.Trim()
			if ($trimmed -eq '0') {
				return $allFiles
			}

			$numbers = $selectionInput -split "[\,\s]+" | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
			$valid = $numbers | Where-Object { $_ -ge 1 -and $_ -le $allFiles.Count } | Select-Object -Unique

			if (-not $valid -or $valid.Count -eq 0) {
				Write-Host ""
				Write-Host "Не выбрано ни одной конфигурации. Попробуйте снова." -ForegroundColor Yellow
				continue
			}

			return $valid | ForEach-Object { $allFiles[$_ - 1] }
		}
	}

	# НОВАЯ ФУНКЦИЯ: выбор папки стратегий
	function Read-StrategiesFolder {
		while ($true) {
			Write-Host ""
			Write-Host "Выберите папку со стратегиями:" -ForegroundColor Cyan
			Write-Host "  [1] Стандартные стратегии (strategies)" -ForegroundColor Gray
			Write-Host "  [2] Направленные стратегии (specstrategies)" -ForegroundColor Gray
			$choice = Read-Host "Введите 1 или 2"
			switch ($choice) {
				'1' { return (Join-Path $rootDir "strategies") }
				'2' { return (Join-Path $rootDir "specstrategies") }
				default { Write-Host "Неверный ввод. Пожалуйста, попробуйте снова." -ForegroundColor Yellow }
			}
		}
	}

	# Проверка прав администратора
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		Write-Host "[ОШИБКА] Запустите скрипт от имени администратора для выполнения тестов" -ForegroundColor Red
		$hasErrors = $true
	} else {
		Write-Host "[ОК] Права администратора обнаружены" -ForegroundColor Green
	}

	# Проверка curl
	if (-not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
		Write-Host "[ОШИБКА] curl.exe не найден" -ForegroundColor Red
		Write-Host "Установите curl или добавьте его в PATH" -ForegroundColor Yellow
		$hasErrors = $true
	} else {
		Write-Host "[ОК] curl.exe найден" -ForegroundColor Green
	}

	# Проверка флага переключения ipset, оставшегося от предыдущего прерванного запуска
	$ipsetFlagFile = Join-Path $rootDir "ipset_switched.flag"
	if (Test-Path $ipsetFlagFile) {
		Write-Host "[ИНФО] Обнаружен флаг переключения ipset от предыдущего запуска. Восстанавливаю ipset..." -ForegroundColor Yellow
		Set-IpsetMode -mode "restore"
		Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
	}

	# Получаем исходное состояние ipset как можно раньше
	$originalIpsetStatus = Get-IpsetStatus

	# Предупреждаем о переключении ipset и о закрытии окна кнопкой X
	if ($originalIpsetStatus -ne "any") {
		Write-Host "[ИНФО] Текущий статус ipset: $originalIpsetStatus" -ForegroundColor Cyan
		Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Ipset будет переключён в 'any' для точных тестов DPI." -ForegroundColor Yellow
		Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Если вы закроете окно кнопкой X, ipset НЕ будет восстановлен немедленно." -ForegroundColor Yellow
		Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Он будет восстановлен автоматически при следующем запуске скрипта." -ForegroundColor Yellow
	}

	# Проверка, установлена ли служба zapret
	if (Test-ZapretServiceConflict) {
		Write-Host "[ОШИБКА] Служба Windows 'zapret' установлена" -ForegroundColor Red
		Write-Host "         Удалите службу перед запуском тестов" -ForegroundColor Yellow
		Write-Host "         Откройте service.bat и выберите 'Remove Services'" -ForegroundColor Yellow
		$hasErrors = $true
	}

	if ($hasErrors) {
		Write-Host ""
		Write-Host "Исправьте указанные выше ошибки и запустите скрипт снова." -ForegroundColor Yellow
		Write-Host "Нажмите любую клавишу для выхода..." -ForegroundColor Yellow
		[void][System.Console]::ReadKey($true)
		exit 1
	}

	$dpiTargets = Build-DpiTargets -CustomUrl $dpiCustomUrl

	# Основной цикл
	while ($true) {
		$globalResults = @()
		
		$testType = Read-TestType
		$mode = Read-ModeSelection

		# === НОВОЕ: выбор папки стратегий ===
		$strategiesPath = Read-StrategiesFolder
		if (-not (Test-Path $strategiesPath)) {
			Write-Host "[ОШИБКА] Папка '$strategiesPath' не найдена." -ForegroundColor Red
			continue
		}

		# Поиск .bat файлов в выбранной папке
		$batFiles = Get-ChildItem -Path $strategiesPath -Filter "*.bat" |
			Where-Object { $_.Name -notlike "service*" } |
			Sort-Object { [Regex]::Replace($_.Name, "(\d+)", { $args[0].Value.PadLeft(8, "0") }) }

		if (-not $batFiles -or $batFiles.Count -eq 0) {
			Write-Host "[ОШИБКА] В папке '$strategiesPath' нет подходящих .bat файлов." -ForegroundColor Red
			continue
		}

		if ($mode -eq 'select') {
			$selected = Read-ConfigSelection -allFiles $batFiles
			$batFiles = @($selected)
		}

		
		# ------------------------------------

		# Загружаем цели один раз для стандартного режима
		$targetList = @()
		$maxNameLen = 10
		if ($testType -eq 'standard') {
			$targetsFile = Join-Path $utilsDir "targets.txt"
			$rawTargets = New-OrderedDict
			if (Test-Path $targetsFile) {
				Get-Content $targetsFile | ForEach-Object {
					if ($_ -match '^\s*(\w+)\s*=\s*"(.+)"\s*$') {
						Add-OrSet -dict $rawTargets -key $matches[1] -val $matches[2]
					}
				}
			}

			if ($rawTargets.Count -eq 0) {
				Write-Host "[ИНФО] targets.txt отсутствует или пуст. Использую значения по умолчанию." -ForegroundColor Gray
				Add-OrSet $rawTargets "Discord Main"           "https://discord.com"
				Add-OrSet $rawTargets "Discord Gateway"        "https://gateway.discord.gg"
				Add-OrSet $rawTargets "Discord CDN"            "https://cdn.discordapp.com"
				Add-OrSet $rawTargets "Discord Updates"        "https://updates.discord.com"
				Add-OrSet $rawTargets "YouTube Web"            "https://www.youtube.com"
				Add-OrSet $rawTargets "YouTube Short"          "https://youtu.be"
				Add-OrSet $rawTargets "YouTube Image"          "https://i.ytimg.com"
				Add-OrSet $rawTargets "YouTube Video Redirect" "https://redirector.googlevideo.com"
				Add-OrSet $rawTargets "Google Main"            "https://www.google.com"
				Add-OrSet $rawTargets "Google Gstatic"         "https://www.gstatic.com"
				Add-OrSet $rawTargets "Cloudflare Web"         "https://www.cloudflare.com"
				Add-OrSet $rawTargets "Cloudflare CDN"         "https://cdnjs.cloudflare.com"
				Add-OrSet $rawTargets "Cloudflare DNS 1.1.1.1" "PING:1.1.1.1"
				Add-OrSet $rawTargets "Cloudflare DNS 1.0.0.1" "PING:1.0.0.1"
				Add-OrSet $rawTargets "Google DNS 8.8.8.8"     "PING:8.8.8.8"
				Add-OrSet $rawTargets "Google DNS 8.8.4.4"     "PING:8.8.4.4"
				Add-OrSet $rawTargets "Quad9 DNS 9.9.9.9"      "PING:9.9.9.9"
			} else {
				Write-Host ""
				Write-Host "[ИНФО] Цели загружены из targets.txt" -ForegroundColor Gray
				Write-Host "[ИНФО] Загружено целей: $($rawTargets.Count)" -ForegroundColor Gray
			}

			foreach ($key in $rawTargets.Keys) {
				$targetList += Convert-Target -Name $key -Value $rawTargets[$key]
			}

			$maxNameLen = ($targetList | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
			if (-not $maxNameLen -or $maxNameLen -lt 10) { $maxNameLen = 10 }
		}

		$originalWinws = Get-WinwsSnapshot

		Write-Host ""
		Write-Host "============================================================" -ForegroundColor Cyan
		Write-Host "                 ТЕСТЫ КОНФИГУРАЦИЙ ZAPRET" -ForegroundColor Cyan
		Write-Host "                 Режим: $($testType.ToUpper())" -ForegroundColor Cyan
		Write-Host "                 Всего конфигураций: $($batFiles.Count.ToString().PadLeft(2))" -ForegroundColor Cyan
		Write-Host "                 Папка: $(Split-Path $strategiesPath -Leaf)" -ForegroundColor Cyan
		Write-Host "============================================================" -ForegroundColor Cyan

		try {
			# Сохраняем исходное состояние ipset и переключаем в 'any' для точных тестов DPI
			if (($originalIpsetStatus -ne "any") -and ($testType -eq 'dpi')) {
				Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Ipset находится в режиме '$originalIpsetStatus'. Переключаю в 'any' для точных тестов DPI..." -ForegroundColor Yellow
				Set-IpsetMode -mode "any"
				# Создаём флаг-файл, указывающий, что ipset был переключён
				"" | Out-File -FilePath $ipsetFlagFile -Encoding UTF8
			}
			Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Тесты могут занять несколько минут. Пожалуйста, подождите..." -ForegroundColor Yellow

			$configNum = 0
			foreach ($file in $batFiles) {
				$configNum++
				Write-Host ""
				Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
				Write-Host "  [$configNum/$($batFiles.Count)] $($file.Name)" -ForegroundColor Yellow
				Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

				# Очистка
				Stop-Zapret

				# Копируем .bat в корень Zapret
				$tempBatPath = Join-Path $rootDir $file.Name
				Copy-Item -Path $file.FullName -Destination $tempBatPath -Force

				Write-Host "  > Запуск конфигурации..." -ForegroundColor Cyan
				$proc = Start-Process -FilePath "cmd.exe" `
					-ArgumentList "/c `"$tempBatPath`"" `
					-WorkingDirectory $rootDir `
					-PassThru -WindowStyle Minimized

				# Ожидание инициализации (можно оставить 10 секунд)
				Start-Sleep -Seconds 10


				if ($testType -eq 'standard') {
					$curlTimeoutSeconds = 5

					# Параллельные проверки целей через пул runspace (быстрее, чем jobs)
					$maxParallel = 8
					$runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxParallel)
					$runspacePool.Open()

					$scriptBlock = {
						param($t, $curlTimeoutSeconds)

						$httpPieces = @()

						if ($t.Url) {
							$tests = @(
								@{ Label = "HTTP";   Args = @("--http1.1") },
								@{ Label = "TLS1.2"; Args = @("--tlsv1.2", "--tls-max", "1.2") },
								@{ Label = "TLS1.3"; Args = @("--tlsv1.3", "--tls-max", "1.3") }
							)

							$baseArgs = @("-I", "-s", "-m", $curlTimeoutSeconds, "-o", "NUL", "-w", "%{http_code}", "--show-error")
							foreach ($test in $tests) {
								try {
									$curlArgs = $baseArgs + $test.Args
									$stderr = $null
									$output = & curl.exe @curlArgs $t.Url 2>&1 | ForEach-Object {
										if ($_ -is [System.Management.Automation.ErrorRecord]) {
											$stderr += $_.Exception.Message + " "
										} else {
											$_
										}
									}
									$httpCode = ($output | Out-String).Trim()

									$dnsHijack = ($stderr -match "Could not resolve host|certificate|SSL certificate problem|self[- ]?signed|certificate verify failed|unable to get local issuer certificate")
									if ($dnsHijack) {
										$httpPieces += "$($test.Label):SSL  "
										continue
									}

									$unsupported = (($LASTEXITCODE -eq 35) -or ($stderr -match "does not support|not supported|protocol\s+'?.+'?\s+not\s+supported|unsupported protocol|TLS.*not supported|Unrecognized option|Unknown option|unsupported option|unsupported feature|schannel"))
									if ($unsupported) {
										$httpPieces += "$($test.Label):UNSUP"
										continue
									}

									$ok = ($LASTEXITCODE -eq 0)
									if ($ok) {
										$httpPieces += "$($test.Label):OK   "
									} else {
										$httpPieces += "$($test.Label):ERROR"
									}
								} catch {
									$httpPieces += "$($test.Label):ERROR"
								}
							}
						}

						$pingResult = "n/a"
						if ($t.PingTarget) {
							try {
								$pings = Test-Connection -ComputerName $t.PingTarget -Count 3 -ErrorAction Stop
								$avg = ($pings | Measure-Object -Property ResponseTime -Average).Average
								$pingResult = "{0:N0} мс" -f $avg
							} catch {
								$pingResult = "Таймаут"
							}
						}

						return (New-Object PSObject -Property @{
							Name       = $t.Name
							HttpTokens = $httpPieces
							PingResult = $pingResult
							IsUrl      = [bool]$t.Url
						})
					}

					$runspaces = @()
					foreach ($target in $targetList) {
						$ps = [powershell]::Create().AddScript($scriptBlock)
						[void]$ps.AddArgument($target)
						[void]$ps.AddArgument($curlTimeoutSeconds)
						$ps.RunspacePool = $runspacePool

						$runspaces += [PSCustomObject]@{
							Powershell = $ps
							Handle     = $ps.BeginInvoke()
						}
					}

					$script:currentLine = "  > Выполнение тестов..."
					Write-Host $script:currentLine -ForegroundColor DarkGray

					$targetResults = @()
					foreach ($rs in $runspaces) {
						try {
							$waitMs = ([int]$curlTimeoutSeconds + 5) * 1000
							$handle = $rs.Handle
							if ($handle -and $handle.AsyncWaitHandle) {
								$completed = $handle.AsyncWaitHandle.WaitOne($waitMs)
								if (-not $completed) {
									Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Runspace для цели не завершился за $waitMs мс; останавливаем runspace..." -ForegroundColor Yellow
									try { $rs.Powershell.Stop() } catch {}
								}
							}
						} catch {
							# игнорируем
						}

						try {
							$targetResults += $rs.Powershell.EndInvoke($rs.Handle)
						} catch {
							Write-Host "[ПРЕДУПРЕЖДЕНИЕ] EndInvoke не удался для runspace; считаем как сбой." -ForegroundColor Yellow
							$targetResults += [PSCustomObject]@{ Name = 'UNKNOWN'; HttpTokens = @('HTTP:ERROR'); PingResult = 'Таймаут'; IsUrl = $true }
						}
						$rs.Powershell.Dispose()
					}

					$runspacePool.Close()
					$runspacePool.Dispose()

					$targetLookup = @{}
					foreach ($res in $targetResults) { $targetLookup[$res.Name] = $res }

					foreach ($target in $targetList) {
						$res = $targetLookup[$target.Name]
						if (-not $res) { continue }

						Write-Host "  $($target.Name.PadRight($maxNameLen))    " -NoNewline

						if ($res.IsUrl -and $res.HttpTokens) {
							foreach ($tok in $res.HttpTokens) {
								$tokColor = "Green"
								if ($tok -match "UNSUP") { $tokColor = "Yellow" }
								elseif ($tok -match "SSL") { $tokColor = "Red" }
								elseif ($tok -match "ERR") { $tokColor = "Red" }
								Write-Host " $tok" -NoNewline -ForegroundColor $tokColor
							}
							Write-Host " | Пинг: " -NoNewline -ForegroundColor DarkGray
							if ($res.PingResult -eq "Таймаут") {
								$pingColor = "Yellow"
							} else {
								$pingColor = "Cyan"
							}
							Write-Host "$($res.PingResult)" -NoNewline -ForegroundColor $pingColor
							Write-Host ""
						} else {
							# Цель только с пингом
							Write-Host " Пинг: " -NoNewline -ForegroundColor DarkGray
							if ($res.PingResult -eq "Таймаут") {
								$pingColor = "Red"
							} else {
								$pingColor = "Cyan"
							}
							Write-Host "$($res.PingResult)" -ForegroundColor $pingColor
						}
					}

					$globalResults += @{ Config = $file.Name; Type = 'standard'; Results = $targetResults }
				} else {
					Write-Host "  > Запуск DPI-проверок..." -ForegroundColor DarkGray
					$dpiResults = Invoke-DpiSuite -Targets $dpiTargets -TimeoutSeconds $dpiTimeoutSeconds -RangeBytes $dpiRangeBytes -WarnMinKB $dpiWarnMinKB -WarnMaxKB $dpiWarnMaxKB -MaxParallel $dpiMaxParallel
					$globalResults += @{ Config = $file.Name; Type = 'dpi'; Results = $dpiResults }
				}

				# Остановка
				Stop-Zapret
				if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
				# Удаляем временную копию .bat
				if (Test-Path $tempBatPath) { Remove-Item $tempBatPath -Force }
			}

			Write-Host ""
			Write-Host "Все тесты завершены." -ForegroundColor Green

			# Аналитика
			$analytics = @{}
			foreach ($res in $globalResults) {
				if ($res.Type -eq 'standard') {
					foreach ($targetRes in $res.Results) {
						$config = $res.Config
						if (-not $analytics.ContainsKey($config)) { $analytics[$config] = @{ OK = 0; ERROR = 0; UNSUP = 0; PingOK = 0; PingFail = 0 } }
						if ($targetRes.IsUrl) {
							foreach ($tok in $targetRes.HttpTokens) {
								if ($tok -match "OK") { $analytics[$config].OK++ }
								elseif ($tok -match "SSL") { $analytics[$config].ERROR++ }
								elseif ($tok -match "ERROR") { $analytics[$config].ERROR++ }
								elseif ($tok -match "UNSUP") { $analytics[$config].UNSUP++ }
							}
						}
						if ($targetRes.PingResult -ne "Таймаут" -and $targetRes.PingResult -ne "n/a") { $analytics[$config].PingOK++ } else { $analytics[$config].PingFail++ }
					}
				} elseif ($res.Type -eq 'dpi') {
					foreach ($targetRes in $res.Results) {
						$config = $res.Config
						if (-not $analytics.ContainsKey($config)) { $analytics[$config] = @{ OK = 0; FAIL = 0; UNSUPPORTED = 0; LIKELY_BLOCKED = 0 } }
						foreach ($line in $targetRes.Lines) {
							if ($line.Status -eq "OK") { $analytics[$config].OK++ }
							elseif ($line.Status -eq "FAIL") { $analytics[$config].FAIL++ }
							elseif ($line.Status -eq "UNSUPPORTED") { $analytics[$config].UNSUPPORTED++ }
							elseif ($line.Status -eq "LIKELY_BLOCKED") { $analytics[$config].LIKELY_BLOCKED++ }
						}
					}
				}
			}

			Write-Host ""
			Write-Host "=== АНАЛИТИКА ===" -ForegroundColor Cyan
			foreach ($config in $analytics.Keys) {
				$a = $analytics[$config]
				if ($a.ContainsKey('PingOK')) {
					Write-Host "$config : HTTP ОК: $($a.OK), ОШИБ: $($a.ERROR), НЕ ПОДДЕРЖ: $($a.UNSUP), Пинг ОК: $($a.PingOK), Неудач: $($a.PingFail)" -ForegroundColor Yellow
				} else {
					Write-Host "$config : ОК: $($a.OK), СБОЙ: $($a.FAIL), НЕ ПОДДЕРЖ: $($a.UNSUPPORTED), ЗАБЛОКИРОВАНО: $($a.LIKELY_BLOCKED)" -ForegroundColor Yellow
				}
			}

			# Определение лучшей стратегии
			$bestConfig = $null
			$maxScore = 0
			$maxPing = -1
			foreach ($config in $analytics.Keys) {
				$a = $analytics[$config]
				$score = $a.OK
				$pingScore = 0
				if ($a.ContainsKey('PingOK')) {
					$pingScore = $a.PingOK
				}
				if ($score -gt $maxScore) {
					$maxScore = $score
					$maxPing = $pingScore
					$bestConfig = $config
				} elseif ($score -eq $maxScore) {
					if ($pingScore -gt $maxPing) {
						$maxPing = $pingScore
						$bestConfig = $config
					}
				}
			}
			Write-Host ""
			Write-Host "Лучшая конфигурация: $bestConfig" -ForegroundColor Green
			Write-Host ""

			# Сохранение в файл
			$dateStr = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
			$resultFile = Join-Path $resultsDir "test_results_$dateStr.txt"
			# Очищаем файл
			"" | Out-File $resultFile -Encoding UTF8
			foreach ($res in $globalResults) {
				$config = $res.Config
				$type = $res.Type
				$results = $res.Results
				Add-Content $resultFile "Config: $config (Type: $type)"
				if ($type -eq 'standard') {
					foreach ($targetRes in $results) {
						$name = $targetRes.Name
						$http = $targetRes.HttpTokens -join ' '
						$ping = $targetRes.PingResult
						Add-Content $resultFile "  $name : $http | Ping: $ping"
					}
				} elseif ($type -eq 'dpi') {
					foreach ($targetRes in $results) {
						$id = $targetRes.TargetId
						$provider = $targetRes.Provider
						Add-Content $resultFile "  Target: $id ($provider)"
						foreach ($line in $targetRes.Lines) {
							$test = $line.TestLabel
							$code = $line.Code
							$size = $line.SizeKB
							$status = $line.Status
							Add-Content $resultFile "    ${test}: code=${code} size=${size} KB status=${status}"
						}
					}
				}
				Add-Content $resultFile ""
			}

			# Добавляем аналитику
			Add-Content $resultFile "=== АНАЛИТИКА ==="
			foreach ($config in $analytics.Keys) {
				$a = $analytics[$config]
				if ($a.ContainsKey('PingOK')) {
					Add-Content $resultFile "$config : HTTP ОК: $($a.OK), ОШИБ: $($a.ERROR), НЕ ПОДДЕРЖ: $($a.UNSUP), Пинг ОК: $($a.PingOK), Неудач: $($a.PingFail)"
				} else {
					Add-Content $resultFile "$config : ОК: $($a.OK), СБОЙ: $($a.FAIL), НЕ ПОДДЕРЖ: $($a.UNSUPPORTED), ЗАБЛОКИРОВАНО: $($a.LIKELY_BLOCKED)"
				}
			}

			Add-Content $resultFile "Лучшая стратегия: $bestConfig"

			Write-Host "Результаты сохранены в $resultFile" -ForegroundColor Green

		} catch {
			Write-Host "[ОШИБКА] Во время тестов произошла ошибка: $($_.Exception.Message)" -ForegroundColor Red
			Write-Host "Стек вызовов: $($_.ScriptStackTrace)" -ForegroundColor Red
			if ($originalIpsetStatus -and $originalIpsetStatus -ne "any") {
				Set-IpsetMode -mode "restore"
			}
			Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
				} finally {
			# Восстановление ресурсов
			Stop-Zapret
			Restore-WinwsSnapshot -snapshot $originalWinws
			if ($originalIpsetStatus -and $originalIpsetStatus -ne "any") {
				Write-Host "[ИНФО] Восстанавливаю исходный режим ipset..." -ForegroundColor DarkGray
				Set-IpsetMode -mode "restore"
			}
			Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
		}

		Write-Host ""
		Write-Host "Нажмите любую клавишу для повторного запуска тестов или закройте окно для выхода..." -ForegroundColor Yellow
		[void][System.Console]::ReadKey($true)
	}  
} catch {
    Write-Host "КРИТИЧЕСКАЯ ОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Стек: $($_.ScriptStackTrace)" -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
    exit 1
}
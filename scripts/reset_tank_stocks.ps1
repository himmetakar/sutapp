#!/usr/bin/env pwsh
# reset_tank_stocks.ps1

$API_KEY = "AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA"
$PROJECT  = "sutapp93"
$BASE     = "https://firestore.googleapis.com/v1/projects/$PROJECT/databases/(default)/documents"

function Coalesce($a, $b) { if ($null -ne $a -and $a -ne "") { $a } else { $b } }

function Get-AllDocs($collection) {
    $url = "$BASE/$collection`?key=$API_KEY&pageSize=300"
    try {
        $result = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        if ($null -ne $result.documents) { return $result.documents } else { return @() }
    } catch { return @() }
}

Write-Host ""
Write-Host "Tank Stok Sifirlama" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# 1. tanklar koleksiyonu → stok alanını 0 yap (sadece sayısal alan, encoding sorunu yok)
Write-Host ""
Write-Host "Tanklar koleksiyonu sifirlaniyor..." -ForegroundColor Yellow
$tankDocs = Get-AllDocs "tanklar"
foreach ($doc in $tankDocs) {
    $ad   = Coalesce $doc.fields.ad.stringValue "?"
    $path = $doc.name

    $patchBody = @{
        fields = @{
            stok = @{ doubleValue = 0.0 }
        }
    }
    $patchUrl = "https://firestore.googleapis.com/v1/${path}?updateMask.fieldPaths=stok&key=$API_KEY"
    try {
        Invoke-RestMethod -Uri $patchUrl -Method Patch -Body ($patchBody | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
        Write-Host "  OK: $ad stok = 0" -ForegroundColor Green
    } catch {
        Write-Host "  HATA $ad : $_" -ForegroundColor Red
    }
}
if ($tankDocs.Count -eq 0) { Write-Host "  (Kayit bulunamadi)" -ForegroundColor Gray }

# 2. araclar embedded array → Node.js ile düzelt (Türkçe karakter bozulmasını önlemek için)
Write-Host ""
Write-Host "Araclar tank stogu Node.js ile sifirlaniyor (UTF-8 guvenli)..." -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$nodeScript = Join-Path $scriptDir "fix_araclar_tank_names.js"
if (Test-Path $nodeScript) {
    node $nodeScript
} else {
    Write-Host "  UYARI: fix_araclar_tank_names.js bulunamadi, atlaniyor." -ForegroundColor Yellow
}

# 3. sut_kabul koleksiyonunu temizle
Write-Host ""
Write-Host "sut_kabul kayitlari siliniyor..." -ForegroundColor Yellow
$kabulDocs = Get-AllDocs "sut_kabul"
foreach ($doc in $kabulDocs) {
    $delUrl = "https://firestore.googleapis.com/v1/$($doc.name)?key=$API_KEY"
    try {
        Invoke-RestMethod -Uri $delUrl -Method Delete | Out-Null
        Write-Host "  OK: Silindi $($doc.name.Split('/')[-1])" -ForegroundColor Green
    } catch {
        Write-Host "  HATA: $_" -ForegroundColor Red
    }
}
if ($kabulDocs.Count -eq 0) { Write-Host "  (Kayit bulunamadi)" -ForegroundColor Gray }

Write-Host ""
Write-Host "Tank stogu sifirlama tamamlandi!" -ForegroundColor Green
Write-Host ""

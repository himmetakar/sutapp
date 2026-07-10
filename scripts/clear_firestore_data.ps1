#!/usr/bin/env pwsh
# clear_firestore_data.ps1
# Firestore'daki işlemsel verileri temizler.
# Kullanıcı, firma, üretici, ürün, fiyat kayıtlarına DOKUNMAZ.

$PROJECT = "sutapp93"

$COLLECTIONS = @(
    "toplamalar",
    "tahsilatlar",
    "avanslar",
    "kesintiler",
    "cezalar",
    "satislar",
    "devirler",
    "urunler_siparisler",
    "giderler",
    "cari_islemler",
    "bildirimler",
    "tank_kayitlari"
)

Write-Host ""
Write-Host "🗑️  Firestore Veri Temizleme — Proje: $PROJECT" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Silinecek koleksiyonlar:" -ForegroundColor Yellow
$COLLECTIONS | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
Write-Host ""
Write-Host "🔒 KORUNAN: users, ureticiler, firmalar, urunler," -ForegroundColor Green
Write-Host "   sut_fiyatlari, toplayici_atamalari, surucu_atamalari" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($col in $COLLECTIONS) {
    Write-Host "Siliniyor: $col ..." -NoNewline
    try {
        $result = firebase firestore:delete $col --project $PROJECT --recursive --force 2>&1
        Write-Host " ✅" -ForegroundColor Green
    } catch {
        Write-Host " ⚠️ (boş veya hata)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Temizleme tamamlandı!" -ForegroundColor Green
Write-Host "   Uygulama artık sıfırdan veri girişine hazır." -ForegroundColor Green
Write-Host ""

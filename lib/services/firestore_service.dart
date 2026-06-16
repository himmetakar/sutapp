import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Firestore'dan gelen herhangi bir değeri güvenle List'e çevirir.
  /// Offline cache bazen Map döndürebilir — bu fonksiyon her iki durumu da ele alır.
  static List<dynamic> _asList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is Map) return value.values.toList(); // offline cache edge case
    return [];
  }


  // Collection References
  CollectionReference get _tanks => _db.collection('tanklar');
  CollectionReference get _drivers => _db.collection('suruculer');
  CollectionReference get _vehicles => _db.collection('araclar');
  CollectionReference get _producers => _db.collection('ureticiler');
  CollectionReference get _collections => _db.collection('toplamalar');

  CollectionReference get _teslimatlar => _db.collection('teslimatlar');
  CollectionReference get _tahsilatlar => _db.collection('tahsilatlar');
  CollectionReference get _users => _db.collection('users');

  // Araç tank güncellemelerini seri hale getirmek için kuyruk.
  // Aynı araca arka arkaya 2 offline süt kaydı geldiğinde race condition oluşmasını önler.
  // Key: araç plakası, Value: son güncelleme future'ı
  static final Map<String, Future<void>> _vehicleUpdateQueue = {};

  /// Araç tankları içindeki stok kopyasını, tanklar koleksiyonundaki gerçek
  /// stok ile senkronize eder. Uygulama açılışında bir kez çağrılır.
  Future<void> syncVehicleTankStocks({String? firma}) async {
    try {
      // Tüm araç tankı tipindeki tankları al
      Query tanksQuery = _tanks.where('tip', isEqualTo: 'arac');
      if (firma != null && firma.isNotEmpty) {
        tanksQuery = tanksQuery.where('firma', isEqualTo: firma);
      }
      final tankSnap = await tanksQuery.get(const GetOptions(source: Source.server));
      
      for (final tankDoc in tankSnap.docs) {
        final tankData = tankDoc.data() as Map<String, dynamic>;
        final String tankAd = tankData['ad'] ?? '';
        final String plate = tankData['arac'] ?? '';
        final double realStok = (tankData['stok'] as num?)?.toDouble() ?? 0.0;
        
        if (tankAd.isEmpty || plate.isEmpty) continue;
        
        // Araç belgesini bul
        final vehicleSnap = await _vehicles
            .where('plaka', isEqualTo: plate)
            .limit(1)
            .get(const GetOptions(source: Source.server));
        
        if (vehicleSnap.docs.isEmpty) continue;
        
        final vehicleDoc = vehicleSnap.docs.first;
        final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
        final List<dynamic> rawTanks = _asList(vehicleData['tanklar']);
        final List<Map<String, dynamic>> vehicleTanks =
            rawTanks.map((t) => Map<String, dynamic>.from(t as Map)).toList();
        
        bool changed = false;
        for (int i = 0; i < vehicleTanks.length; i++) {
          if (vehicleTanks[i]['ad'] == tankAd) {
            final double copyStok = (vehicleTanks[i]['stok'] as num?)?.toDouble() ?? 0.0;
            if ((copyStok - realStok).abs() > 0.01) {
              // Kopyalanmış değer gerçekten farklı — güncelle
              vehicleTanks[i]['stok'] = realStok;
              changed = true;
              print('[syncVehicleTankStocks] Araç "$plate" tank "$tankAd": $copyStok → $realStok LT');
            }
            break;
          }
        }
        
        if (changed) {
          await vehicleDoc.reference.update({'tanklar': vehicleTanks});
        }
      }
      print('[syncVehicleTankStocks] Senkronizasyon tamamlandı.');
    } catch (e) {
      print('[syncVehicleTankStocks] Hata: $e');
    }
  }

  /// Tüm tankları siler, araç-sürücü bağlantılarını temizler ve her sürücüye
  /// yeni bir tank atar. Tek çağrıyla tam temiz kurulum sağlar.
  /// [firma]: Hangi firma için yapılacak.
  /// [kapasite]: Oluşturulacak her tank için LT kapasitesi (varsayılan 2000).
  Future<String> resetAndAssignAllTanks(String firma, {double kapasite = 2000.0}) async {
    final log = StringBuffer();
    try {
      // ── 1. Mevcut tanklar koleksiyonunu tamamen sil ───────────────────────
      final existingTanks = await _tanks.where('firma', isEqualTo: firma).get();
      for (final doc in existingTanks.docs) {
        await doc.reference.delete();
      }
      log.writeln('✓ ${existingTanks.docs.length} tank silindi.');

      // ── 2. Araçların tanklar + suruculer array'ini temizle ────────────────
      final vehicles = await _vehicles.where('firma', isEqualTo: firma).get();
      for (final doc in vehicles.docs) {
        await doc.reference.update({'tanklar': [], 'suruculer': []});
      }
      log.writeln('✓ ${vehicles.docs.length} araç temizlendi.');

      // ── 3. Sürücüleri çek ─────────────────────────────────────────────────
      final driversSnap = await _drivers.where('firma', isEqualTo: firma).get();
      final List<Map<String, dynamic>> drivers = driversSnap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
      log.writeln('✓ ${drivers.length} sürücü bulundu.');

      if (drivers.isEmpty) {
        log.writeln('⚠ Firma için kayıtlı sürücü bulunamadı!');
        return log.toString();
      }

      if (vehicles.docs.isEmpty) {
        log.writeln('⚠ Firma için kayıtlı araç bulunamadı!');
        return log.toString();
      }

      // ── 4. Her sürücüye sırayla bir araç ve tank ata ─────────────────────
      int tankIndex = 1;
      for (int i = 0; i < drivers.length; i++) {
        final driver = drivers[i];
        final String ad = driver['ad'] ?? '';
        final String soyad = driver['soyad'] ?? '';
        final String fullName = '$ad $soyad'.trim();

        if (fullName.isEmpty) {
          log.writeln('⚠ Sürücü #$i ismi boş, atlandı.');
          continue;
        }

        // Araç ata: sürücü sayısından fazlaysa son aracı paylaş
        final vehicleDoc = vehicles.docs[i < vehicles.docs.length ? i : vehicles.docs.length - 1];
        final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
        final String plate = vehicleData['plaka'] ?? '';

        if (plate.isEmpty) {
          log.writeln('⚠ Araç plakası boş, $fullName atlandı.');
          continue;
        }

        // Tank adı: "Sürücü Adı Tankı" formatı
        final String tankAd = '$fullName Tankı';
        final String tankKod = 'TANK-${tankIndex.toString().padLeft(3, '0')}';

        // tanklar koleksiyonuna yeni belge ekle
        final newTankRef = await _tanks.add({
          'ad': tankAd,
          'kod': tankKod,
          'kap': kapasite,
          'stok': 0.0,
          'tip': 'arac',
          'arac': plate,
          'firma': firma,
          'durum': 'aktif',
          'suruculer': [fullName],
        });
        log.writeln('✓ Tank oluşturuldu: "$tankAd" → $plate (${newTankRef.id})');

        // Araç belgesine tank ve sürücü ekle
        final List<dynamic> existingVehicleTanks =
            _asList((vehicleDoc.data() as Map<String, dynamic>)['tanklar']);
        // Önceki iterasyonda eklenenler dahil, güncel veriyi çek
        final freshVehicleSnap = await vehicleDoc.reference.get();
        final freshData = freshVehicleSnap.data() as Map<String, dynamic>;
        final List<dynamic> currentTanks = _asList(freshData['tanklar']);
        final List<dynamic> currentDrivers = _asList(freshData['suruculer']);

        final updatedTanks = [...currentTanks, {
          'ad': tankAd,
          'stok': 0.0,
          'kap': kapasite,
          'suruculer': [fullName],
        }];
        final updatedDrivers = [...currentDrivers];
        if (!updatedDrivers.contains(fullName)) updatedDrivers.add(fullName);

        await vehicleDoc.reference.update({
          'tanklar': updatedTanks,
          'suruculer': updatedDrivers,
        });
        log.writeln('✓ $plate aracına "$fullName" ve "$tankAd" eklendi.');

        tankIndex++;
      }

      log.writeln('\n✅ Tüm işlemler tamamlandı. $tankIndex-1 tank oluşturuldu.');
    } catch (e, st) {
      log.writeln('\n❌ Hata: $e\n$st');
    }
    return log.toString();
  }

  Future<void> _clearCollection(CollectionReference ref) async {
    final snap = await ref.get();
    for (var doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  /// Sadece süt toplama kayıtlarını (toplamalar) siler ve tüm tank stoklarını
  /// 0'a sıfırlar. Yapısal veriler (sürücüler, araçlar, tanklar, müşteriler)
  /// korunur. Temiz bir başlangıç için kullanılır.
  Future<String> resetMilkCollectionsAndStocks(String firma) async {
    final log = StringBuffer();
    try {
      // 1. Toplamalar (süt alım kayıtları) sil
      final toplamalar = await _db.collection('toplamalar')
          .where('firma', isEqualTo: firma).get();
      for (final d in toplamalar.docs) { await d.reference.delete(); }
      log.writeln('✓ ${toplamalar.docs.length} toplama kaydı silindi.');

      // 2. tanklar koleksiyonundaki stok → 0
      final tankDocs = await _tanks.where('firma', isEqualTo: firma).get();
      for (final d in tankDocs.docs) {
        await d.reference.update({'stok': 0.0});
      }
      log.writeln('✓ ${tankDocs.docs.length} tankın stoğu sıfırlandı.');

      // 3. araclar.tanklar[] array içindeki stok kopyaları → 0
      final vehicleDocs = await _vehicles.where('firma', isEqualTo: firma).get();
      for (final vDoc in vehicleDocs.docs) {
        final data = vDoc.data() as Map<String, dynamic>;
        final List<dynamic> rawTanks = _asList(data['tanklar']);
        if (rawTanks.isEmpty) continue;
        final updated = rawTanks.map((t) {
          final m = Map<String, dynamic>.from(t as Map);
          m['stok'] = 0.0;
          return m;
        }).toList();
        await vDoc.reference.update({'tanklar': updated});
      }
      log.writeln('✓ ${vehicleDocs.docs.length} araçtaki tank kopyaları sıfırlandı.');

      log.writeln('\n✅ Tamamlandı. Artık yeni süt girişi yapabilirsiniz.');
    } catch (e) {
      log.writeln('\n❌ Hata: $e');
    }
    return log.toString();
  }

  /// Sütlere ait tüm rakamsal/işlemsel verileri temizler ve tank/araç stokları ile üretici süt toplamlarını sıfırlar.
  /// Yapısal veriler (sürücüler, araçlar, tanklar, üreticiler ve atamalar) korunur.
  Future<String> clearAllMilkData(String firma) async {
    final log = StringBuffer();
    try {
      final db = FirebaseFirestore.instance;

      // 1. Toplamalar (Süt toplamaları) sil
      final toplamalar = await db.collection('toplamalar')
          .where('firma', isEqualTo: firma).get();
      for (final d in toplamalar.docs) { await d.reference.delete(); }
      log.writeln('✓ ${toplamalar.docs.length} süt toplama kaydı silindi.');

      // 2. Süt Kabul (Süt boşaltma talepleri ve kabulleri) sil
      final sutKabul = await db.collection('sut_kabul')
          .where('firma', isEqualTo: firma).get();
      for (final d in sutKabul.docs) { await d.reference.delete(); }
      log.writeln('✓ ${sutKabul.docs.length} süt kabul kaydı silindi.');

      // 3. Fireler (Süt fireleri) sil
      final fireler = await db.collection('fireler')
          .where('firma', isEqualTo: firma).get();
      for (final d in fireler.docs) { await d.reference.delete(); }
      log.writeln('✓ ${fireler.docs.length} fire kaydı silindi.');

      // 4. Teslimatlar (Süt teslimatları) sil
      final teslimatlar = await db.collection('teslimatlar')
          .where('firma', isEqualTo: firma).get();
      for (final d in teslimatlar.docs) { await d.reference.delete(); }
      log.writeln('✓ ${teslimatlar.docs.length} süt teslimat kaydı silindi.');

      // 5. Süt Satışları (Süt satışları) sil
      final sutSatislari = await db.collection('sut_satislari')
          .where('firma', isEqualTo: firma).get();
      for (final d in sutSatislari.docs) { await d.reference.delete(); }
      log.writeln('✓ ${sutSatislari.docs.length} süt satış kaydı silindi.');

      // 6. Tanklar koleksiyonundaki stok → 0
      final tankDocs = await db.collection('tanklar').where('firma', isEqualTo: firma).get();
      for (final d in tankDocs.docs) {
        await d.reference.update({'stok': 0.0});
      }
      log.writeln('✓ ${tankDocs.docs.length} tankın stoğu sıfırlandı.');

      // 7. Araçlar.tanklar[] array içindeki stok kopyaları → 0
      final vehicleDocs = await db.collection('araclar').where('firma', isEqualTo: firma).get();
      for (final vDoc in vehicleDocs.docs) {
        final data = vDoc.data();
        final List<dynamic> rawTanks = _asList(data['tanklar']);
        if (rawTanks.isEmpty) continue;
        final updated = rawTanks.map((t) {
          final m = Map<String, dynamic>.from(t as Map);
          m['stok'] = 0.0;
          return m;
        }).toList();
        await vDoc.reference.update({'tanklar': updated});
      }
      log.writeln('✓ ${vehicleDocs.docs.length} araçtaki tank kopyaları sıfırlandı.');

      // 8. Üreticilerin toplam süt miktarı → 0
      final ureticiler = await db.collection('ureticiler')
          .where('firmalar', arrayContains: firma).get();
      for (final d in ureticiler.docs) {
        await d.reference.update({'total': 0.0});
      }
      log.writeln('✓ ${ureticiler.docs.length} üreticinin toplam süt miktarı sıfırlandı.');

      log.writeln('\n✅ Süt verileri başarıyla temizlendi.');
    } catch (e) {
      log.writeln('\n❌ Hata: $e');
    }
    return log.toString();
  }


  /// Sadece sayısal/işlem verilerini sıfırlar. Yapısal veriler (üreticiler,
  /// tanklar, araçlar, sürücüler) korunur.
  Future<void> resetNumericalData(String firma) async {
    // 1. Toplama kayıtları (sürücü süt alımları)
    final toplamalar = await _db.collection('toplamalar')
        .where('firma', isEqualTo: firma).get();
    for (var d in toplamalar.docs) { await d.reference.delete(); }

    // 2. Teslimatlar
    final teslimatlar = await _db.collection('teslimatlar')
        .where('firma', isEqualTo: firma).get();
    for (var d in teslimatlar.docs) { await d.reference.delete(); }

    // 3. Satışlar
    final satislar = await _db.collection('satislar')
        .where('firma', isEqualTo: firma).get();
    for (var d in satislar.docs) { await d.reference.delete(); }

    // 4. Faturalar
    final faturalar = await _db.collection('faturalar')
        .where('firma', isEqualTo: firma).get();
    for (var d in faturalar.docs) { await d.reference.delete(); }

    // 5. Avanslar
    final avanslar = await _db.collection('avanslar')
        .where('firma', isEqualTo: firma).get();
    for (var d in avanslar.docs) { await d.reference.delete(); }

    // 6. Tahsilatlar
    final tahsilatlar = await _tahsilatlar
        .where('firma', isEqualTo: firma).get();
    for (var d in tahsilatlar.docs) { await d.reference.delete(); }

    // 7. Cezalar
    final cezalar = await _db.collection('cezalar')
        .where('firma', isEqualTo: firma).get();
    for (var d in cezalar.docs) { await d.reference.delete(); }

    // 8. Kesintiler
    final kesintiler = await _db.collection('kesintiler')
        .where('firma', isEqualTo: firma).get();
    for (var d in kesintiler.docs) { await d.reference.delete(); }

    // 9. Süt kabul
    final sutKabul = await _db.collection('sut_kabul')
        .where('firma', isEqualTo: firma).get();
    for (var d in sutKabul.docs) { await d.reference.delete(); }

    // 10. Süt analiz
    final sutAnaliz = await _db.collection('sut_analiz')
        .where('firma', isEqualTo: firma).get();
    for (var d in sutAnaliz.docs) { await d.reference.delete(); }

    // 11. Süt ödemeleri (ödeme_gecmisi)
    final sutOdemeleri = await _db.collection('odeme_gecmisi')
        .where('firma', isEqualTo: firma).get();
    for (var d in sutOdemeleri.docs) { await d.reference.delete(); }

    // 12. Devirler
    final devirler = await _db.collection('devirler')
        .where('firma', isEqualTo: firma).get();
    for (var d in devirler.docs) { await d.reference.delete(); }

    // 13. Tank stoklarını sıfırla (yapıyı koru, sadece stok = 0)
    final tanklar = await _tanks.where('firma', isEqualTo: firma).get();
    for (var d in tanklar.docs) {
      await d.reference.update({'stok': 0.0});
    }

    // 14. Araç tankı stoklarını sıfırla
    final araclar = await _vehicles.where('firma', isEqualTo: firma).get();
    for (var d in araclar.docs) {
      final data = d.data() as Map<String, dynamic>;
      final tankList = _asList(data['tanklar'])
          .map((t) => Map<String, dynamic>.from(t as Map))
          .toList();
      for (var t in tankList) { t['stok'] = 0.0; }
      await d.reference.update({'tanklar': tankList});
    }

    // 15. Üretici toplamlarını sıfırla
    final ureticiler = await _producers
        .where('firmalar', arrayContains: firma).get();
    for (var d in ureticiler.docs) {
      await d.reference.update({'total': 0.0});
    }
  }

  // Initialize initial mock data if the collection is empty, or force reset
  Future<void> initializeMockDataIfNeeded({bool forceReset = false}) async {
    try {
      if (forceReset) {
        await _clearCollection(_tanks);
        await _clearCollection(_drivers);
        await _clearCollection(_vehicles);
        await _clearCollection(_producers);
        await _clearCollection(_collections);
        await _clearCollection(_teslimatlar);
        await _clearCollection(_tahsilatlar);
        await _clearCollection(_db.collection('avanslar'));
        await _clearCollection(_db.collection('sut_fiyatlari'));
        await _clearCollection(_db.collection('cezalar'));
        await _clearCollection(_db.collection('kesintiler'));
        await _clearCollection(_db.collection('faturalar'));
        await _clearCollection(_db.collection('sut_kabul'));
        await _clearCollection(_db.collection('sut_analiz'));
        await _clearCollection(_db.collection('urunler_siparisler'));
        await _clearCollection(_db.collection('satislar'));
        await _clearCollection(_db.collection('bildirimler'));
        await _clearCollection(_db.collection('duyurular'));
        await _clearCollection(_db.collection('devirler'));
      }

      // 1. Tanks
      final tankSnap = await _tanks.limit(1).get();
      if (tankSnap.docs.isEmpty) {
        final mockTanks = [
          {'ad': 'Yayla Merkez Tankı', 'kap': 15000.0, 'stok': 0.0, 'tip': 'merkez', 'arac': '', 'firma': 'Kayseri Çiftlik'},
          {'ad': 'Kaya Merkez Tankı', 'kap': 10000.0, 'stok': 0.0, 'tip': 'merkez', 'arac': '', 'firma': 'Sivas Süt A.Ş.'},
          {'ad': 'Tank-01', 'kap': 3000.0, 'stok': 0.0, 'tip': 'arac', 'arac': '34 TR 100', 'firma': 'Kayseri Çiftlik'},
          {'ad': 'Tank-02', 'kap': 2000.0, 'stok': 0.0, 'tip': 'arac', 'arac': '34 TR 200', 'firma': 'Sivas Süt A.Ş.'},
        ];
        for (var t in mockTanks) {
          await _tanks.add(t);
        }
      }

      // 2. Drivers
      final driverSnap = await _drivers.limit(1).get();
      if (driverSnap.docs.isEmpty) {
        final mockDrivers = [
          {'ad': 'Ahmet', 'soyad': 'Kara', 'tel': '0532 100 0001', 'email': 'surucu@sutapp.com', 'tc': '123456789**', 'uretici': 3, 'active': true, 'firma': 'Kayseri Çiftlik'},
          {'ad': 'Veli', 'soyad': 'Yıldız', 'tel': '0532 100 0002', 'email': 'veli@firma.com', 'tc': '234567890**', 'uretici': 2, 'active': true, 'firma': 'Sivas Süt A.Ş.'},
        ];
        for (var d in mockDrivers) {
          await _drivers.add(d);
        }
      }

      // 3. Vehicles
      final vehicleSnap = await _vehicles.limit(1).get();
      if (vehicleSnap.docs.isEmpty) {
        final mockVehicles = [
          {
            'plaka': '34 TR 100',
            'suruculer': ['Ahmet Kara'],
            'tanklar': [
              {'ad': 'Tank-01', 'stok': 0.0, 'kap': 3000.0}
            ],
            'active': true,
            'firma': 'Kayseri Çiftlik'
          },
          {
            'plaka': '34 TR 200',
            'suruculer': ['Veli Yıldız'],
            'tanklar': [
              {'ad': 'Tank-02', 'stok': 0.0, 'kap': 2000.0}
            ],
            'active': true,
            'firma': 'Sivas Süt A.Ş.'
          },
        ];
        for (var v in mockVehicles) {
          await _vehicles.add(v);
        }
      }

      // 4. Producers
      final prodSnap = await _producers.get();
      if (prodSnap.docs.isEmpty) {
        final mockProducers = [
          {'name': 'Mehmet Yılmaz', 'phone': '0532 111 2233', 'group': 'Yayla Çiftliği', 'bolge': 'Kocasinan', 'total': 0.0, 'avg': 30.0, 'firmalar': ['Kayseri Çiftlik']},
          {'name': 'Fatma Korkmaz', 'phone': '0533 222 3344', 'group': 'Yayla Çiftliği', 'bolge': 'Kocasinan', 'total': 0.0, 'avg': 30.0, 'firmalar': ['Kayseri Çiftlik']},
          {'name': 'Ali Özdemir', 'phone': '0534 333 4455', 'group': 'Kızıltepe Mah.', 'bolge': 'Talas', 'total': 0.0, 'avg': 30.0, 'firmalar': ['Kayseri Çiftlik']},
          {'name': 'Ayşe Şahin', 'phone': '0535 444 5566', 'group': 'Dağyolu Çiftlikleri', 'bolge': 'Merkez', 'total': 0.0, 'avg': 30.0, 'firmalar': ['Sivas Süt A.Ş.']},
          {'name': 'Hüseyin Kaya', 'phone': '0536 555 6677', 'group': 'Akarsu Bölgesi', 'bolge': 'Merkez', 'total': 0.0, 'avg': 30.0, 'firmalar': ['Sivas Süt A.Ş.']},
        ];
        for (var p in mockProducers) {
          await _producers.add(p);
        }
      } else {
        // Migration: Add 'firmalar' and 'bolge' to any existing producers missing them
        for (var doc in prodSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final updates = <String, dynamic>{};
          if (!data.containsKey('firmalar')) {
            final name = data['name'] ?? '';
            final firmalar = <String>[];
            if (name == 'Ayşe Şahin' || name == 'Hüseyin Kaya') {
              firmalar.add('Sivas Süt A.Ş.');
            } else {
              firmalar.add('Kayseri Çiftlik');
            }
            updates['firmalar'] = firmalar;
          }
          if (!data.containsKey('bolge')) {
            final name = data['name'] ?? '';
            if (name == 'Mehmet Yılmaz' || name == 'Fatma Korkmaz') {
              updates['bolge'] = 'Kocasinan';
            } else if (name == 'Ali Özdemir') {
              updates['bolge'] = 'Talas';
            } else {
              updates['bolge'] = 'Merkez';
            }
          }
          if (updates.isNotEmpty) {
            await doc.reference.update(updates);
          }
        }
      }

      // 8. Companies (firmalar)
      final CollectionReference companiesRef = _db.collection('firmalar');
      final compSnap = await companiesRef.limit(1).get();
      if (compSnap.docs.isEmpty) {
        final mockCompanies = [
          {
            'ad': 'Kayseri Çiftlik',
            'tel': '0352 111 2233',
            'adres': 'Kayseri Organize Sanayi',
            'yetkili': 'Hasan Yılmaz',
            'maxPersonel': 10,
            'maxUretici': 100,
            'maxArac': 5,
            'maxMesaj': 20,
            'abonelikBitis': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'ad': 'Sivas Süt A.Ş.',
            'tel': '0346 222 3344',
            'adres': 'Sivas OSB',
            'yetkili': 'Murat Kaya',
            'maxPersonel': 10,
            'maxUretici': 100,
            'maxArac': 5,
            'maxMesaj': 20,
            'abonelikBitis': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
            'createdAt': FieldValue.serverTimestamp(),
          }
        ];
        for (var c in mockCompanies) {
          await companiesRef.add(c);
        }
      }

      // 9. Cari Firmalar (Partner Companies)
      final CollectionReference cariFirmalarRef = _db.collection('cari_firmalar');
      final cariFirmaSna = await cariFirmalarRef.limit(1).get();
      if (cariFirmaSna.docs.isEmpty) {
        final List<Map<String, dynamic>> mockCariFirmalar = [
          {'ad': 'Sütaş A.Ş.', 'tip': 'alici', 'tel': '0850 200 0788', 'eposta': 'iletisim@sutas.com.tr', 'adres': 'Karacabey / Bursa', 'firma': 'Kayseri Çiftlik'},
          {'ad': 'Pınar Süt', 'tip': 'alici', 'tel': '0850 210 0724', 'eposta': 'info@pinar.com.tr', 'adres': 'Kemalpaşa / İzmir', 'firma': 'Kayseri Çiftlik'},
          {'ad': 'Karakaya Yem Sanayi', 'tip': 'tedarikci', 'tel': '0352 222 1100', 'eposta': 'iletisim@karakayayem.com', 'adres': 'Kocasinan / Kayseri', 'firma': 'Kayseri Çiftlik'},
          {'ad': 'Sütaş A.Ş.', 'tip': 'alici', 'tel': '0850 200 0788', 'eposta': 'iletisim@sutas.com.tr', 'adres': 'Karacabey / Bursa', 'firma': 'Sivas Süt A.Ş.'},
          {'ad': 'Karakaya Yem Sanayi', 'tip': 'tedarikci', 'tel': '0352 222 1100', 'eposta': 'iletisim@karakayayem.com', 'adres': 'Kocasinan / Kayseri', 'firma': 'Sivas Süt A.Ş.'},
        ];
        for (var cf in mockCariFirmalar) {
          cf['timestamp'] = FieldValue.serverTimestamp();
          await cariFirmalarRef.add(cf);
        }
      }

      // Fidanım Süt specific data check and additions
      final fidComp = await companiesRef.where('ad', isEqualTo: 'Fidanım Süt').limit(1).get();
      if (fidComp.docs.isEmpty) {
        await companiesRef.add({
          'ad': 'Fidanım Süt',
          'tel': '0352 999 8877',
          'adres': 'Melikgazi / Kayseri',
          'yetkili': 'Hakan Fidan',
          'maxPersonel': 10,
          'maxUretici': 100,
          'maxArac': 5,
          'maxMesaj': 20,
          'abonelikBitis': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        await _tanks.add({'ad': 'Fidanım Merkez Tankı', 'kap': 20000.0, 'stok': 0.0, 'tip': 'merkez', 'arac': '', 'firma': 'Fidanım Süt'});
        await _tanks.add({'ad': 'Fidanım Tank-01', 'kap': 4000.0, 'stok': 0.0, 'tip': 'arac', 'arac': '34 FID 50', 'firma': 'Fidanım Süt'});
        
        await _drivers.add({'ad': 'Hasan', 'soyad': 'Fidan', 'tel': '0532 100 0003', 'email': 'hasanfidan@sutapp.com', 'tc': '345678901**', 'uretici': 1, 'active': true, 'firma': 'Fidanım Süt'});
        
        await _vehicles.add({
          'plaka': '34 FID 50',
          'suruculer': ['Hasan Fidan'],
          'tanklar': [
            {'ad': 'Fidanım Tank-01', 'stok': 0.0, 'kap': 4000.0}
          ],
          'active': true,
          'firma': 'Fidanım Süt'
        });
        
        await _producers.add({'name': 'Anıl Demir', 'phone': '0537 888 7766', 'group': 'Fidanım Köyü', 'bolge': 'Melikgazi', 'total': 0.0, 'avg': 50.0, 'firmalar': ['Fidanım Süt']});
      }

      // ── CLEANUP: Remove Kemal Demir completely from the system ──
      // This runs every time to ensure the old demo user is purged.
      final kemalProducers = await _producers.where('name', isEqualTo: 'Kemal Demir').get();
      for (var doc in kemalProducers.docs) {
        await doc.reference.delete();
      }
      final kemalAtamalar = await _db.collection('toplayici_atamalari').where('hedefAd', isEqualTo: 'Kemal Demir').get();
      for (var doc in kemalAtamalar.docs) {
        await doc.reference.delete();
      }

      // ── REPAIR: Ensure Hasan Fidan always exists in suruculer ──
      // This runs every time to auto-heal if the record was accidentally deleted.
      final hasanCheck = await _drivers
          .where('ad', isEqualTo: 'Hasan')
          .where('soyad', isEqualTo: 'Fidan')
          .limit(1)
          .get();
      if (hasanCheck.docs.isEmpty) {
        await _drivers.add({
          'ad': 'Hasan',
          'soyad': 'Fidan',
          'tel': '0532 100 0003',
          'email': 'hasanfidan@sutapp.com',
          'tc': '345678901**',
          'uretici': 1,
          'active': true,
          'firma': 'Fidanım Süt',
          'canAddCustomer': true,
          'canEditCustomer': true,
          'canCreateOrder': false,
        });
        print('[REPAIR] Hasan Fidan suruculer koleksiyonuna yeniden eklendi.');
      }

      final anilCheck = await _producers.where('name', isEqualTo: 'Anıl Demir').limit(1).get();
      if (anilCheck.docs.isEmpty) {
        await _producers.add({
          'name': 'Anıl Demir',
          'phone': '0537 888 7766',
          'group': 'Fidanım Köyü',
          'bolge': 'Melikgazi',
          'total': 0.0,
          'avg': 50.0,
          'firmalar': ['Fidanım Süt'],
        });
      } else {
        // Fix phone if it has the old duplicate value
        final anilDoc = anilCheck.docs.first;
        final anilData = anilDoc.data() as Map<String, dynamic>;
        if (anilData['phone'] == '0532 999 8877') {
          await anilDoc.reference.update({'phone': '0537 888 7766'});
        }
      }
    } catch (e) {
      print('Mock initialization error: $e');
    }
  }

  // --- TANKS API ---
  Stream<QuerySnapshot> getTanksStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _tanks.where('firma', isEqualTo: firma).snapshots();
    }
    return _tanks.where('firma', isEqualTo: '___NONE___').snapshots();
  }

  Future<void> addTank(Map<String, dynamic> tank) async {
    await _tanks.add(tank);
  }

  // --- DRIVERS API ---
  Stream<QuerySnapshot> getDriversStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _drivers.where('firma', isEqualTo: firma).snapshots();
    }
    return _drivers.where('firma', isEqualTo: '___NONE___').snapshots();
  }

  Future<void> addDriver(Map<String, dynamic> driver) async {
    await _drivers.add(driver);
  }

  // --- VEHICLES API ---
  Stream<QuerySnapshot> getVehiclesStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _vehicles.where('firma', isEqualTo: firma).snapshots();
    }
    return _vehicles.where('firma', isEqualTo: '___NONE___').snapshots();
  }

  Future<void> addVehicle(Map<String, dynamic> vehicle) async {
    await _vehicles.add(vehicle);
  }

  Future<void> updateVehicle(String docId, Map<String, dynamic> vehicle) async {
    await _vehicles.doc(docId).update(vehicle);
  }

  // --- PRODUCERS API ---
  Stream<QuerySnapshot> getProducersStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _producers.where('firmalar', arrayContains: firma).snapshots();
    }
    return _producers.where('firmalar', arrayContains: '___NONE___').snapshots();
  }

  Future<void> addProducer({
    required String name,
    required String phone,
    required String group,
    required String bolge,
    required double avg,
    required String firma,
    String? lastMilkType,
    String? customerType,
    String? mapsLink,
    double? latitude,
    double? longitude,
  }) async {
    // Try to find by phone first, then by name
    QuerySnapshot query = await _producers.where('phone', isEqualTo: phone).limit(1).get();
    if (query.docs.isEmpty) {
      query = await _producers.where('name', isEqualTo: name).limit(1).get();
    }

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final updates = <String, dynamic>{
        'firmalar': FieldValue.arrayUnion([firma]),
        'bolge': bolge,
        'group': group,
      };
      if (lastMilkType != null) {
        updates['lastMilkType'] = lastMilkType;
      }
      if (customerType != null) {
        updates['customerType'] = customerType;
      }
      if (mapsLink != null && mapsLink.isNotEmpty) {
        updates['mapsLink'] = mapsLink;
      }
      if (latitude != null && longitude != null) {
        updates['latitude'] = latitude;
        updates['longitude'] = longitude;
      }
      await doc.reference.update(updates);
    } else {
      final data = <String, dynamic>{
        'name': name,
        'phone': phone,
        'group': group,
        'bolge': bolge,
        'avg': avg,
        'total': 0.0,
        'firmalar': [firma]
      };
      if (lastMilkType != null) {
        data['lastMilkType'] = lastMilkType;
      }
      data['customerType'] = customerType ?? 'sut';
      if (mapsLink != null && mapsLink.isNotEmpty) {
        data['mapsLink'] = mapsLink;
      }
      if (latitude != null && longitude != null) {
        data['latitude'] = latitude;
        data['longitude'] = longitude;
      }
      await _producers.add(data);
    }
  }

  // --- COLLECTIONS API ---
  Stream<QuerySnapshot> getCollectionsStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _collections.where('firma', isEqualTo: firma).snapshots();
    }
    return _collections.where('firma', isEqualTo: '___NONE___').snapshots();
  }

  Future<void> addCollection(Map<String, dynamic> collection) async {
    collection['timestamp'] = FieldValue.serverTimestamp();
    await _collections.add(collection);
  }

  Future<QuerySnapshot> getQueryWithCachePriority(Query query) async {
    // 1. Önce cache'e bak, veri varsa hemen dön
    try {
      final snap = await query.get(const GetOptions(source: Source.cache));
      if (snap.docs.isNotEmpty) return snap;
    } catch (_) {}
    // 2. Sunucudan kısa timeout ile dene
    try {
      return await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    // 3. Son çare: cache'den al (boş dahi olsa — offline'da takılmaz)
    try {
      return await query
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Hiçbir şey yoksa boş sonuç dön yerine default get() ile dene, 5 sn limit
      return query.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => query.get(const GetOptions(source: Source.cache)),
      );
    }
  }

  Future<DocumentSnapshot> getDocWithCachePriority(DocumentReference docRef) async {
    // 1. Önce cache'e bak
    try {
      final doc = await docRef.get(const GetOptions(source: Source.cache));
      if (doc.exists) return doc;
    } catch (_) {}
    // 2. Sunucudan kısa timeout ile dene
    try {
      return await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    // 3. Son çare: cache (offline'da takılmaz)
    try {
      return await docRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return docRef.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => docRef.get(const GetOptions(source: Source.cache)),
      );
    }
  }

  // --- BUSINESS LOGIC ACTIONS ---

  Future<void> recordMilkCollection({
    required String producerName,
    required String tankName,
    required double miktar,
    String? driverName,
    String? vehiclePlate,
    String? region,
    String? firma,
    String? sutTipi,
    String? customerType,
    String? vakit,
    String? kalite,
    DateTime? customDate,
    bool notifyProducer = true,
  }) async {
    // Guard: üretici adı boş olamaz — boş kayıt Firestore'a yazılmasın
    if (producerName.trim().isEmpty) {
      throw ArgumentError('[recordMilkCollection] producerName boş olamaz — kayıt iptal edildi.');
    }

    // Resolve company name if not explicitly passed
    String resolvedFirma = firma ?? '';
    if (resolvedFirma.isEmpty) {
      final tankQuery = await getQueryWithCachePriority(_tanks.where('ad', isEqualTo: tankName).limit(1));
      if (tankQuery.docs.isNotEmpty) {
        resolvedFirma = tankQuery.docs.first['firma'] ?? '';
      }
    }

    final targetDate = customDate ?? DateTime.now();

    // 1. Add collection record
    final timeStr = DateFormat('HH:mm').format(targetDate);
    await _collections.add({
      'u': producerName,
      'm': miktar,
      's': timeStr,
      'sync': true,
      'sr': driverName ?? 'Yönetici',
      'km': vehiclePlate ?? '-',
      'b': region ?? 'Merkez',
      'tank': tankName,
      'tarih': DateFormat('dd.MM.yyyy').format(targetDate), // tarih: offline'da da filtrelenebilsin
      'timestamp': customDate != null ? Timestamp.fromDate(customDate) : FieldValue.serverTimestamp(),
      'firma': resolvedFirma,
      'tip': sutTipi ?? 'So\u011fuk S\u00fct',
      'customerType': customerType ?? 'sut',
      'vakit': (vakit != null && vakit.isNotEmpty)
          ? vakit
          : ((targetDate.hour >= 2 && targetDate.hour < 14) ? 'Sabah' : 'Akşam'),
      if (kalite != null) 'kalite': kalite,
    });

    // 2. Update tank stock in tanklar collection using increment() to prevent offline race conditions.
    // FieldValue.increment() is applied atomically on the server, so two offline writes both get
    // correctly accumulated when the device comes back online (no overwrite bug).
    QuerySnapshot tankQuery = await getQueryWithCachePriority(_tanks.where('ad', isEqualTo: tankName).limit(1));

    // Cache miss durumunda doğrudan server'dan dene (tank ID değişmiş olabilir)
    if (tankQuery.docs.isEmpty) {
      print('[recordMilkCollection] Tank "$tankName" cache\'de bulunamadı, server deneniyor...');
      try {
        tankQuery = await _tanks.where('ad', isEqualTo: tankName).limit(1).get();
      } catch (e) {
        print('[recordMilkCollection] Server sorgusu da başarısız: $e');
      }
    }

    if (tankQuery.docs.isNotEmpty) {
      var tankDoc = tankQuery.docs.first;
      // Use increment so offline queued writes stack correctly
      try {
        await tankDoc.reference.update({'stok': FieldValue.increment(miktar)});
        print('[recordMilkCollection] Tank "$tankName" stok +$miktar LT güncellendi');
      } catch (e) {
        print('[recordMilkCollection] Tank güncelleme hatası (ID: ${tankDoc.id}): $e');
        if (e.toString().contains('not-found') || e.toString().contains('NOT_FOUND')) {
          try {
            print('[recordMilkCollection] Stale tank document ID detected in cache. Querying server directly...');
            final freshTankQuery = await _tanks.where('ad', isEqualTo: tankName).limit(1).get(const GetOptions(source: Source.server));
            if (freshTankQuery.docs.isNotEmpty) {
              tankDoc = freshTankQuery.docs.first;
              await tankDoc.reference.update({'stok': FieldValue.increment(miktar)});
              print('[recordMilkCollection] Tank "$tankName" stok +$miktar LT güncellendi (Fresh ID: ${tankDoc.id})');
              tankQuery = freshTankQuery; // Update query ref for downstream code
            } else {
              print('[recordMilkCollection] Tank "$tankName" sunucuda da bulunamadı.');
            }
          } catch (serverErr) {
            print('[recordMilkCollection] Sunucu üzerinden tank güncelleme hatası: $serverErr');
          }
        }
      }

      // 3. Araç tankının embedded array'ini güncelle — race condition'ı önlemek için seri kuyruk
      final tipValue = tankDoc['tip'];
      if (tipValue == 'arac') {
        final plate = tankDoc['arac'] as String? ?? vehiclePlate ?? '';
        if (plate.isNotEmpty) {
          // Aynı araç için önceki güncelleme tamamlanmadan yeni okuma yapma
          final qKey = 'vehicle_$plate';
          _vehicleUpdateQueue[qKey] = (_vehicleUpdateQueue[qKey] ?? Future<void>.value())
              .then((_) async {
            try {
              // Her zaman sunucudan taze veri oku — cache'deki stale index
              // 'tanklar.$i.stok' dot-notation'ını yanlış tanka yazabilir.
              QuerySnapshot vehicleQuery;
              try {
                vehicleQuery = await _vehicles
                    .where('plaka', isEqualTo: plate)
                    .limit(1)
                    .get(const GetOptions(source: Source.server));
              } catch (_) {
                vehicleQuery = await _vehicles
                    .where('plaka', isEqualTo: plate)
                    .limit(1)
                    .get();
              }

              if (vehicleQuery.docs.isNotEmpty) {
                final vehicleDoc = vehicleQuery.docs.first;
                // Tüm tank array'ini oku, eşleşeni güncelle, tamamını geri yaz
                final List<dynamic> rawTanks =
                    _asList((vehicleDoc.data() as Map<String, dynamic>)['tanklar']);
                final List<Map<String, dynamic>> vehicleTanks = rawTanks
                    .map((t) => Map<String, dynamic>.from(t as Map))
                    .toList();

                bool updated = false;
                for (int i = 0; i < vehicleTanks.length; i++) {
                  if (vehicleTanks[i]['ad'] == tankName) {
                    final double curStok =
                        (vehicleTanks[i]['stok'] as num?)?.toDouble() ?? 0.0;
                    vehicleTanks[i]['stok'] =
                        (curStok + miktar).clamp(0.0, double.infinity);
                    updated = true;
                    break;
                  }
                }

                if (updated) {
                  await vehicleDoc.reference.update({'tanklar': vehicleTanks});
                  print('[recordMilkCollection] Araç tank $tankName stok +$miktar LT güncellendi (read-modify-write)');
                } else {
                  print('[recordMilkCollection] ⚠️ Araç "$plate" içinde tank "$tankName" bulunamadı!');
                }
              } else {
                print('[recordMilkCollection] Araç "$plate" bulunamadı!');
              }
            } catch (e) {
              print('[recordMilkCollection] Araç tank güncelleme hatası: $e');
            }
          }, onError: (e) {
            print('[recordMilkCollection] Vehicle queue hata: $e');
          });
          await _vehicleUpdateQueue[qKey]!;
        }
      }

      // Not: _collections zaten 'toplamalar' koleksiyonunu referans ediyor.
      // Üsté çift yazıyı önlemek için burada ayrıca toplamalar.add() YAPILMIYOR.
    } else {
      print('[recordMilkCollection] ⚠️ Tank "$tankName" BULUNAMADI — stok güncellenemedi!');
    }

    // 4. Update producer total milk & last milk type preference
    // FieldValue.increment kullan — offline\'da stale cache okumasını önler
    QuerySnapshot prodQuery = await getQueryWithCachePriority(_producers.where('name', isEqualTo: producerName).limit(1));
    if (prodQuery.docs.isEmpty) {
      try {
        prodQuery = await _producers.where('name', isEqualTo: producerName).limit(1).get();
      } catch (_) {}
    }
    if (prodQuery.docs.isNotEmpty) {
      var prodDoc = prodQuery.docs.first;
      try {
        await prodDoc.reference.update({
          'total': FieldValue.increment(miktar),
          'lastMilkType': sutTipi ?? 'So\u011fuk S\u00fct',
        });
      } catch (updateErr) {
        print('[recordMilkCollection] Üretici güncelleme hatası: $updateErr');
        if (updateErr.toString().contains('not-found') || updateErr.toString().contains('NOT_FOUND')) {
          try {
            print('[recordMilkCollection] Stale producer document ID detected. Querying server directly...');
            final freshProdQuery = await _producers.where('name', isEqualTo: producerName).limit(1).get(const GetOptions(source: Source.server));
            if (freshProdQuery.docs.isNotEmpty) {
              prodDoc = freshProdQuery.docs.first;
              await prodDoc.reference.update({
                'total': FieldValue.increment(miktar),
                'lastMilkType': sutTipi ?? 'So\u011fuk S\u00fct',
              });
              print('[recordMilkCollection] Üretici "$producerName" total güncellendi (Fresh ID: ${prodDoc.id})');
            }
          } catch (serverErr) {
            print('[recordMilkCollection] Sunucu üzerinden üretici güncelleme hatası: $serverErr');
          }
        }
      }
    } else {
      print('[recordMilkCollection] ⚠️ Üretici "$producerName" bulunamadı — total güncellenemedi!');
    }

    // 5. Send notification to the producer (fire-and-forget, never blocks the record)
    if (notifyProducer) {
      Future.microtask(() async {
        try {
          final String resolvedDriver = driverName ?? 'Yönetici';
          final String resolvedPlate = vehiclePlate != null && vehiclePlate.isNotEmpty ? ' ($vehiclePlate)' : '';
          await sendNotification(
            recipientName: producerName,
            role: 'uretici',
            baslik: 'Süt Alımı Gerçekleşti',
            icerik: '$miktar lt sütünüz $resolvedDriver$resolvedPlate tarafından teslim alınmıştır.',
            type: 'sut_alim',
          );
        } catch (e) {
          print('Süt alım bildirimi gönderilemedi: $e');
        }
      });
    }
  }

  /// Delete a milk collection record and reverse stock changes
  Future<void> deleteMilkCollection(String docId) async {
    final docRef = _collections.doc(docId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final data = docSnap.data() as Map<String, dynamic>;
    final double miktar = (data['m'] as num?)?.toDouble() ?? 0.0;
    final String tankName = data['tank'] ?? '';
    final String producerName = data['u'] ?? '';
    final String vehiclePlate = data['km'] ?? '';

    // 1. Subtract from tank stock using increment(-miktar) for atomicity
    if (tankName.isNotEmpty) {
      final tankQuery = await _tanks.where('ad', isEqualTo: tankName).limit(1).get();
      if (tankQuery.docs.isNotEmpty) {
        final tankDoc = tankQuery.docs.first;
        await tankDoc.reference.update({'stok': FieldValue.increment(-miktar)});

        // Update in vehicle document as well
        if (tankDoc['tip'] == 'arac' && vehiclePlate.isNotEmpty) {
          final vehicleQuery = await _vehicles.where('plaka', isEqualTo: vehiclePlate).limit(1).get();
          if (vehicleQuery.docs.isNotEmpty) {
            final vehicleDoc = vehicleQuery.docs.first;
            final List<dynamic> vehicleTanks = _asList(vehicleDoc['tanklar'])
                .map((t) => Map<String, dynamic>.from(t as Map))
                .toList();
            for (int i = 0; i < vehicleTanks.length; i++) {
              if (vehicleTanks[i]['ad'] == tankName) {
                final double oldStok = (vehicleTanks[i]['stok'] as num?)?.toDouble() ?? 0.0;
                vehicleTanks[i]['stok'] = (oldStok - miktar).clamp(0.0, double.infinity);
                break;
              }
            }
            await vehicleDoc.reference.update({'tanklar': vehicleTanks});
          }
        }
      }
    }

    // 2. Update producer total
    if (producerName.isNotEmpty) {
      final prodQuery = await _producers.where('name', isEqualTo: producerName).limit(1).get();
      if (prodQuery.docs.isNotEmpty) {
        final prodDoc = prodQuery.docs.first;
        final currentTotal = (prodDoc['total'] as num).toDouble();
        final newTotal = (currentTotal - miktar).clamp(0.0, double.infinity);
        await prodDoc.reference.update({'total': newTotal});
      }
    }

    // 3. Delete the collection document
    await docRef.delete();
  }

  /// Update a milk collection record and adjust stock changes
  Future<void> updateMilkCollection(String docId, double newMiktar) async {
    final docRef = _collections.doc(docId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final data = docSnap.data() as Map<String, dynamic>;
    final double oldMiktar = (data['m'] as num?)?.toDouble() ?? 0.0;
    final String tankName = data['tank'] ?? '';
    final String producerName = data['u'] ?? '';
    final String vehiclePlate = data['km'] ?? '';

    final diff = newMiktar - oldMiktar;
    if (diff == 0) return;

    // 1. Update document
    await docRef.update({'m': newMiktar});

    // 2. Adjust tank stock
    if (tankName.isNotEmpty) {
      final tankQuery = await _tanks.where('ad', isEqualTo: tankName).limit(1).get();
      if (tankQuery.docs.isNotEmpty) {
        final tankDoc = tankQuery.docs.first;
        final currentStock = (tankDoc['stok'] as num).toDouble();
        final newStock = (currentStock + diff).clamp(0.0, double.infinity);
        await tankDoc.reference.update({'stok': newStock});

        // Update in vehicle document as well
        if (tankDoc['tip'] == 'arac' && vehiclePlate.isNotEmpty) {
          final vehicleQuery = await _vehicles.where('plaka', isEqualTo: vehiclePlate).limit(1).get();
          if (vehicleQuery.docs.isNotEmpty) {
            final vehicleDoc = vehicleQuery.docs.first;
            final List<dynamic> vehicleTanks = _asList(vehicleDoc['tanklar'])
                .map((t) => Map<String, dynamic>.from(t as Map))
                .toList();
            for (int i = 0; i < vehicleTanks.length; i++) {
              if (vehicleTanks[i]['ad'] == tankName) {
                vehicleTanks[i]['stok'] = newStock;
                break;
              }
            }
            await vehicleDoc.reference.update({'tanklar': vehicleTanks});
          }
        }
      }
    }

    // 3. Adjust producer total
    if (producerName.isNotEmpty) {
      final prodQuery = await _producers.where('name', isEqualTo: producerName).limit(1).get();
      if (prodQuery.docs.isNotEmpty) {
        final prodDoc = prodQuery.docs.first;
        final currentTotal = (prodDoc['total'] as num).toDouble();
        final newTotal = (currentTotal + diff).clamp(0.0, double.infinity);
        await prodDoc.reference.update({'total': newTotal});
      }
    }
  }

  Future<void> recordMilkTransfer({
    required String vehiclePlate,
    required String sourceTankName,
    required String targetTankName,
    required double miktar,
  }) async {
    // 1. Subtract from source tank
    final sourceQuery = await _tanks.where('ad', isEqualTo: sourceTankName).limit(1).get();
    if (sourceQuery.docs.isNotEmpty) {
      final sourceDoc = sourceQuery.docs.first;
      final currentSourceStock = (sourceDoc['stok'] as num).toDouble();
      final newSourceStock = (currentSourceStock - miktar).clamp(0.0, double.infinity);
      await sourceDoc.reference.update({'stok': newSourceStock});

      // Update in vehicle document as well
      final vehicleQuery = await _vehicles.where('plaka', isEqualTo: vehiclePlate).limit(1).get();
      if (vehicleQuery.docs.isNotEmpty) {
        final vehicleDoc = vehicleQuery.docs.first;
        final List<dynamic> vehicleTanks = _asList(vehicleDoc['tanklar'])
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        for (int i = 0; i < vehicleTanks.length; i++) {
          if (vehicleTanks[i]['ad'] == sourceTankName) {
            vehicleTanks[i]['stok'] = newSourceStock;
            break;
          }
        }
        await vehicleDoc.reference.update({'tanklar': vehicleTanks});
      }
    }

    // 2. Add to target tank
    final targetQuery = await _tanks.where('ad', isEqualTo: targetTankName).limit(1).get();
    String targetFirma = '';
    if (targetQuery.docs.isNotEmpty) {
      final targetDoc = targetQuery.docs.first;
      targetFirma = targetDoc['firma'] ?? '';
      final currentTargetStock = (targetDoc['stok'] as num).toDouble();
      final newTargetStock = (currentTargetStock + miktar).clamp(0.0, double.infinity);
      await targetDoc.reference.update({'stok': newTargetStock});
    }

    // 3. Log to teslimatlar
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    await _db.collection('teslimatlar').add({
      'plaka': vehiclePlate,
      'kaynakTank': sourceTankName,
      'hedefTank': targetTankName,
      'miktar': miktar,
      'saat': timeStr,
      'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
      'timestamp': FieldValue.serverTimestamp(),
      'firma': targetFirma,
    });

    // 4. Send notification to the driver(s) of this vehicle
    try {
      final vehicleQuery = await _vehicles.where('plaka', isEqualTo: vehiclePlate).limit(1).get();
      if (vehicleQuery.docs.isNotEmpty) {
        final vehicleDoc = vehicleQuery.docs.first;
        final List<dynamic> driversList = _asList(vehicleDoc['suruculer']);
        for (var d in driversList) {
          if (d is String) {
            await sendNotification(
              recipientName: d,
              role: 'surucu',
              baslik: 'Merkez Tank Teslimatı',
              icerik: '$miktar lt süt aracınızdan ($vehiclePlate) $targetTankName tankına aktarılmıştır.',
              type: 'depo_aktarim',
            );
          }
        }
      }
    } catch (e) {
      print('Depo transfer bildirimi gönderilemedi: $e');
    }
  }

  Future<void> transferTankStock({
    required String sutKabulId,
    required String sourceTankName,
    required String targetTankName,
    required double miktar, // accepted amount
    double? beyanEdilenMiktar, // declared amount
    required String vehiclePlate,
    required String driverName,
  }) async {
    final db = FirebaseFirestore.instance;
    final kabulDocRef = db.collection('sut_kabul').doc(sutKabulId);

    // Find source tank
    final sourceQuery = await db.collection('tanklar')
        .where('ad', isEqualTo: sourceTankName)
        .limit(1)
        .get();

    // Find target tank
    final targetQuery = await db.collection('tanklar')
        .where('ad', isEqualTo: targetTankName)
        .limit(1)
        .get();

    if (sourceQuery.docs.isEmpty || targetQuery.docs.isEmpty) {
      throw Exception('Kaynak veya hedef tank bulunamadı.');
    }

    final sourceDoc = sourceQuery.docs.first;
    final targetDoc = targetQuery.docs.first;
    final double declared = beyanEdilenMiktar ?? miktar;

    // 1. Update source tank stok (vehicle tank loses the ENTIRE declared/requested amount)
    final double sourceCurrent = (sourceDoc.data()['stok'] as num?)?.toDouble() ?? 0.0;
    await sourceDoc.reference.update({'stok': (sourceCurrent - declared).clamp(0.0, double.infinity)});

    // 2. Update target tank stok (center tank gets only the accepted amount)
    final double targetCurrent = (targetDoc.data()['stok'] as num?)?.toDouble() ?? 0.0;
    await targetDoc.reference.update({'stok': (targetCurrent + miktar).clamp(0.0, double.infinity)});

    // 3. Update vehicle tanks if source is vehicle tank
    if (sourceDoc.data()['tip'] == 'arac' && vehiclePlate.isNotEmpty) {
      final vehicleQuery = await db.collection('araclar')
          .where('plaka', isEqualTo: vehiclePlate)
          .limit(1)
          .get();
      if (vehicleQuery.docs.isNotEmpty) {
        final vehicleDoc = vehicleQuery.docs.first;
        final List<dynamic> vehicleTanks = _asList(vehicleDoc['tanklar'])
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        for (int i = 0; i < vehicleTanks.length; i++) {
          if (vehicleTanks[i]['ad'] == sourceTankName) {
            vehicleTanks[i]['stok'] = (sourceCurrent - declared).clamp(0.0, double.infinity);
            break;
          }
        }
        await vehicleDoc.reference.update({'tanklar': vehicleTanks});
      }

      // Mark matching collections in 'toplamalar' as bosaltildi: true
      final collectionsToUpdate = await db.collection('toplamalar')
          .where('km', isEqualTo: vehiclePlate)
          .where('tank', isEqualTo: sourceTankName)
          .get();
      final batch = db.batch();
      for (final doc in collectionsToUpdate.docs) {
        final d = doc.data();
        if (d['bosaltildi'] != true) {
          batch.update(doc.reference, {'bosaltildi': true});
        }
      }
      await batch.commit();
    }

    // 4. Update sut_kabul document state
    final double fire = (declared - miktar).clamp(0.0, double.infinity);
    final double fazla = (miktar - declared).clamp(0.0, double.infinity);
    await kabulDocRef.update({
      'durum': 'Kabul Edildi',
      'kabulEdilenMiktar': miktar,
      'fire': fire,
      'fazla': fazla,
    });

    // Write a fire document if there is fire
    final String resolvedFirma = targetDoc.data()['firma'] ?? '';
    if (fire > 0) {
      await db.collection('fireler').add({
        'sutKabulId': sutKabulId,
        'plaka': vehiclePlate,
        'surucuName': driverName,
        'kaynak': sourceTankName,
        'hedef': targetTankName,
        'beyan': declared,
        'kabul': miktar,
        'fire': fire,
        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
        'timestamp': FieldValue.serverTimestamp(),
        'firma': resolvedFirma,
      });
    }

    // 5. Log a delivery record to 'teslimatlar' for audit
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    await db.collection('teslimatlar').add({
      'sutKabulId': sutKabulId,
      'plaka': vehiclePlate,
      'kaynakTank': sourceTankName,
      'hedefTank': targetTankName,
      'miktar': miktar,
      'saat': timeStr,
      'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
      'timestamp': FieldValue.serverTimestamp(),
      'firma': resolvedFirma,
    });

    // 6. Send success notification to the driver
    try {
      String notificationBody = '';
      if (fire > 0) {
        notificationBody = '$sourceTankName tankından $targetTankName tankına boşaltma işleminiz $miktar LT olarak kabul edildi. (${fire.toStringAsFixed(1)} LT fire)';
      } else {
        notificationBody = '$sourceTankName tankından $targetTankName tankına $miktar LT boşaltma işleminiz onaylandı.';
      }
      await sendNotification(
        recipientName: driverName,
        role: 'surucu',
        baslik: 'Boşaltma Talebi Onaylandı',
        icerik: notificationBody,
        type: 'depo_aktarim',
      );
    } catch (_) {}
  }

  Future<void> rejectTankUnload(String sutKabulId, String driverName, String sourceTankName, String targetTankName) async {
    await FirebaseFirestore.instance.collection('sut_kabul').doc(sutKabulId).update({'durum': 'Reddedildi'});
    
    // Send rejection notification to the driver
    try {
      await sendNotification(
        recipientName: driverName,
        role: 'surucu',
        baslik: 'Boşaltma Talebi Reddedildi',
        icerik: '$sourceTankName tankından $targetTankName tankına boşaltma talebiniz reddedilmiştir.',
        type: 'depo_aktarim',
      );
    } catch (_) {}
  }

  Future<void> updateAcceptedTankStock({
    required String sutKabulId,
    required double newAcceptedAmount,
  }) async {
    final db = FirebaseFirestore.instance;
    final kabulDocRef = db.collection('sut_kabul').doc(sutKabulId);
    final kabulDoc = await kabulDocRef.get();

    if (!kabulDoc.exists) {
      throw Exception('Kabul belgesi bulunamadı.');
    }

    final data = kabulDoc.data() as Map<String, dynamic>;
    final String durum = data['durum'] ?? '';
    if (durum != 'Kabul Edildi') {
      throw Exception('Yalnızca kabul edilmiş kayıtlar düzenlenebilir.');
    }

    final String hedef = data['hedef'] ?? '';
    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
    final double oldAcceptedAmount = ((data['kabulEdilenMiktar'] ?? data['miktar']) as num).toDouble();

    if (hedef.isEmpty) {
      throw Exception('Hedef tank bilgisi eksik.');
    }

    // Find target tank
    final targetQuery = await db.collection('tanklar')
        .where('ad', isEqualTo: hedef)
        .limit(1)
        .get();

    if (targetQuery.docs.isEmpty) {
      throw Exception('Hedef tank bulunamadı.');
    }

    final targetDoc = targetQuery.docs.first;
    final double targetCurrent = (targetDoc.data()['stok'] as num?)?.toDouble() ?? 0.0;

    // Calculate new target stock
    final double newTargetStock = (targetCurrent - oldAcceptedAmount + newAcceptedAmount).clamp(0.0, double.infinity);

    // 1. Update target tank stock
    await targetDoc.reference.update({'stok': newTargetStock});

    // 2. Calculate new fire and fazla
    final double newFire = (miktar - newAcceptedAmount).clamp(0.0, double.infinity);
    final double newFazla = (newAcceptedAmount - miktar).clamp(0.0, double.infinity);

    // 3. Update sut_kabul document state
    await kabulDocRef.update({
      'kabulEdilenMiktar': newAcceptedAmount,
      'fire': newFire,
      'fazla': newFazla,
      'editedAt': FieldValue.serverTimestamp(),
      'previousMiktar': oldAcceptedAmount,
    });

    // 4. Update or Delete matching 'fireler' record
    final fireQuery = await db.collection('fireler')
        .where('sutKabulId', isEqualTo: sutKabulId)
        .limit(1)
        .get();

    if (fireQuery.docs.isNotEmpty) {
      final fireDoc = fireQuery.docs.first;
      if (newFire > 0) {
        await fireDoc.reference.update({
          'kabul': newAcceptedAmount,
          'fire': newFire,
        });
      } else {
        await fireDoc.reference.delete();
      }
    } else if (newFire > 0) {
      final String resolvedFirma = targetDoc.data()['firma'] ?? '';
      await db.collection('fireler').add({
        'sutKabulId': sutKabulId,
        'plaka': data['plaka'] ?? '',
        'surucuName': data['sr'] ?? data['surucuName'] ?? (data['email'] ?? ''),
        'kaynak': data['kaynak'] ?? '',
        'hedef': hedef,
        'beyan': miktar,
        'kabul': newAcceptedAmount,
        'fire': newFire,
        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
        'timestamp': FieldValue.serverTimestamp(),
        'firma': resolvedFirma,
      });
    }

    // 5. Update matching 'teslimatlar' record
    final teslimatQuery = await db.collection('teslimatlar')
        .where('sutKabulId', isEqualTo: sutKabulId)
        .limit(1)
        .get();

    if (teslimatQuery.docs.isNotEmpty) {
      final teslimatDoc = teslimatQuery.docs.first;
      await teslimatDoc.reference.update({
        'miktar': newAcceptedAmount,
      });
    }
  }

  Future<void> approveToplayiciTeklif(String notificationId, String teklifId) async {
    final db = FirebaseFirestore.instance;
    final teklifRef = db.collection('toplayici_teklifleri').doc(teklifId);
    final docSnap = await teklifRef.get();
    if (!docSnap.exists) {
      throw Exception('Teklif bulunamadı.');
    }

    final data = docSnap.data() as Map<String, dynamic>;
    final durum = data['durum'] ?? 'beklemede';
    if (durum != 'beklemede') {
      throw Exception('Bu teklif zaten işlenmiş.');
    }

    final tip = data['tip'] as String?;
    final toplayici = data['toplayici'] as String? ?? '';
    final firma = data['firma'] as String? ?? '';

    if (tip == 'ekle') {
      final yeniData = data['yeniData'] as Map<String, dynamic>?;
      if (yeniData != null) {
        final name = yeniData['name'] as String? ?? '';
        final phone = yeniData['phone'] as String? ?? '';
        final group = yeniData['group'] as String? ?? '';
        final bolge = yeniData['bolge'] as String? ?? '';
        final avg = (yeniData['avg'] ?? 50.0) as num;
        final lat = yeniData['latitude'] as double?;
        final lng = yeniData['longitude'] as double?;
        final mapsLink = yeniData['mapsLink'] as String?;
        final milkType = yeniData['lastMilkType'] as String? ?? 'So\u011fuk S\u00fct';

        // 1. Create producer
        await db.collection('ureticiler').add({
          'name': name,
          'phone': phone,
          'group': group,
          'bolge': bolge,
          'avg': avg.toDouble(),
          'total': 0.0,
          'firmalar': [firma],
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (mapsLink != null) 'mapsLink': mapsLink,
          'lastMilkType': milkType,
        });

        // 2. Automatically assign the producer to the collector/toplayici
        await db.collection('toplayici_atamalari').add({
          'toplayici': toplayici,
          'hedefTip': 'uretici',
          'hedefAd': name,
          'firma': firma,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } else if (tip == 'duzenle') {
      final ureticiId = data['ureticiId'] as String?;
      final yeniData = data['yeniData'] as Map<String, dynamic>?;
      final eskiData = data['eskiData'] as Map<String, dynamic>?;
      if (ureticiId != null && yeniData != null) {
        final name = yeniData['name'] as String? ?? '';
        final phone = yeniData['phone'] as String? ?? '';
        final group = yeniData['group'] as String? ?? '';
        final bolge = yeniData['bolge'] as String? ?? '';
        final lat = yeniData['latitude'] as double?;
        final lng = yeniData['longitude'] as double?;
        final mapsLink = yeniData['mapsLink'] as String?;
        final milkType = yeniData['lastMilkType'] as String?;

        // 1. Update producer
        await db.collection('ureticiler').doc(ureticiId).update({
          'name': name,
          'phone': phone,
          'group': group,
          'bolge': bolge,
          'latitude': lat,
          'longitude': lng,
          'mapsLink': mapsLink,
          if (milkType != null) 'lastMilkType': milkType,
        });

        // 2. Update assignments in toplayici_atamalari if name changed
        final oldName = eskiData?['name'] as String? ?? '';
        if (oldName.isNotEmpty && name.isNotEmpty && oldName != name) {
          final atamalar = await db.collection('toplayici_atamalari')
              .where('hedefAd', isEqualTo: oldName)
              .where('firma', isEqualTo: firma)
              .get();
          for (var doc in atamalar.docs) {
            await doc.reference.update({'hedefAd': name});
          }
        }
      }
    } else if (tip == 'silme') {
      final ureticiId = data['ureticiId'] as String?;
      final eskiData = data['eskiData'] as Map<String, dynamic>?;
      final ureticiAd = eskiData?['name'] as String? ?? '';
      if (ureticiId != null) {
        // 1. Get producer to check companies
        final prodSnap = await db.collection('ureticiler').doc(ureticiId).get();
        if (prodSnap.exists) {
          final pData = prodSnap.data() as Map<String, dynamic>;
          final firmalar = List<String>.from(pData['firmalar'] ?? []);
          firmalar.remove(firma);
          if (firmalar.isEmpty) {
            // Delete producer document completely
            await prodSnap.reference.delete();
          } else {
            // Just remove this firma from the producer
            await prodSnap.reference.update({'firmalar': firmalar});
          }
        }

        // 2. Delete assignments in toplayici_atamalari
        if (ureticiAd.isNotEmpty) {
          final atamalar = await db.collection('toplayici_atamalari')
              .where('hedefAd', isEqualTo: ureticiAd)
              .where('firma', isEqualTo: firma)
              .get();
          for (var doc in atamalar.docs) {
            await doc.reference.delete();
          }
        }
      }
    }

    // Update status to onaylandi
    await teklifRef.update({'durum': 'onaylandi'});
    // Mark notification read
    await markNotificationRead(notificationId);
  }

  Future<void> rejectToplayiciTeklif(String notificationId, String teklifId) async {
    final db = FirebaseFirestore.instance;
    await db.collection('toplayici_teklifleri').doc(teklifId).update({'durum': 'reddedildi'});
    await markNotificationRead(notificationId);
  }

  Future<void> recordTahsilat({
    required String producerName,
    required double tutar,
    String? odemeYontemi,
    String? aciklama,
    String? firma,
    String? tip,
    DateTime? date,
  }) async {
    String resolvedFirma = firma ?? '';
    if (resolvedFirma.isEmpty) {
      final prodQuery = await _producers.where('name', isEqualTo: producerName).limit(1).get();
      if (prodQuery.docs.isNotEmpty) {
        final list = prodQuery.docs.first['firmalar'] as List?;
        if (list != null && list.isNotEmpty) {
          resolvedFirma = list.first as String;
        }
      }
    }

    final targetDate = date ?? DateTime.now();

    await _db.collection('tahsilatlar').add({
      'uretici': producerName,
      'tutar': tutar,
      'odemeYontemi': odemeYontemi ?? 'Nakit',
      'aciklama': aciklama ?? '',
      'tarih': DateFormat('dd.MM.yyyy').format(targetDate),
      'saat': DateFormat('HH:mm').format(targetDate),
      'timestamp': Timestamp.fromDate(targetDate),
      'firma': resolvedFirma,
      if (tip != null) 'tip': tip,
    });
  }

  String getTahsilatType(Map<String, dynamic> data) {
    if (data['tip'] != null) {
      return data['tip'] as String;
    }
    // Legacy fallback
    final desc = (data['aciklama'] as String? ?? '').toLowerCase();
    
    // Check for collection keywords first (even if they also contain the word "ödeme")
    if (desc.contains('tahsilat') || 
        desc.contains('tahsil') || 
        desc.contains('yem') || 
        desc.contains('avans geri') || 
        desc.contains('borç') || 
        desc.contains('borc') || 
        desc.contains('ürün') || 
        desc.contains('urun') || 
        desc.contains('alım') || 
        desc.contains('alim') || 
        desc.contains('kabul')) {
      return 'tahsilat';
    }
    
    // Check for milk payment keywords
    if (desc.contains('süt') || 
        desc.contains('sut') || 
        desc.contains('bedel') || 
        desc.contains('ödeme') || 
        desc.contains('odeme') || 
        desc.contains('toplu') || 
        desc.contains('hakediş') || 
        desc.contains('hakedis')) {
      return 'odeme';
    }
    
    return 'tahsilat';
  }

  // --- DRIVER SPECIFIC STREAMS ---

  Stream<QuerySnapshot> getDriverVehicleStream(String driverName, {String? firma}) {
    Query q = _vehicles.where('suruculer', arrayContains: driverName);
    if (firma != null && firma.isNotEmpty) {
      q = q.where('firma', isEqualTo: firma);
    }
    return q.limit(1).snapshots();
  }

  Stream<QuerySnapshot> getDriverCollectionsStream(String driverName) {
    return _collections
        .where('sr', isEqualTo: driverName)
        .snapshots(includeMetadataChanges: true); // offline pending → spinner açılır/kapanır
  }

  // --- PRODUCER SPECIFIC STREAMS ---

  Stream<QuerySnapshot> getProducerCollectionsStream(String producerName) {
    return _collections.where('u', isEqualTo: producerName).snapshots();
  }

  // --- MILK PRICES API ---
  CollectionReference get _milkPrices => _db.collection('sut_fiyatlari');

  Stream<QuerySnapshot> getMilkPricesStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _milkPrices.where('firma', isEqualTo: firma).snapshots();
    }
    return _milkPrices.snapshots();
  }

  Future<void> saveMilkPrice(Map<String, dynamic> priceData) async {
    final query = await _milkPrices
        .where('firma', isEqualTo: priceData['firma'])
        .where('tip', isEqualTo: priceData['tip'])
        .where('hedef', isEqualTo: priceData['hedef'])
        .limit(1)
        .get();

    priceData['timestamp'] = FieldValue.serverTimestamp();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update(priceData);
    } else {
      await _milkPrices.add(priceData);
    }
  }

  // --- AVANSLAR API ---
  CollectionReference get _avanslar => _db.collection('avanslar');

  Stream<QuerySnapshot> getAvanslarStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _avanslar.where('firma', isEqualTo: firma).snapshots();
    }
    return _avanslar.snapshots();
  }

  Stream<QuerySnapshot> getAllAvanslarStream() {
    return _avanslar.snapshots();
  }

  Future<void> addAvans(Map<String, dynamic> avansData) async {
    avansData['timestamp'] ??= FieldValue.serverTimestamp();
    await _avanslar.add(avansData);
  }

  Future<void> deleteAvans(String docId) async {
    await _avanslar.doc(docId).delete();
  }

  // --- CEZALAR API ---
  CollectionReference get _cezalar => _db.collection('cezalar');

  Stream<QuerySnapshot> getCezalarStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _cezalar.where('firma', isEqualTo: firma).snapshots();
    }
    return _cezalar.snapshots();
  }

  Stream<QuerySnapshot> getAllCezalarStream() {
    return _cezalar.snapshots();
  }

  Future<void> addCeza(Map<String, dynamic> cezaData) async {
    cezaData['timestamp'] ??= FieldValue.serverTimestamp();
    await _cezalar.add(cezaData);
  }

  Future<void> deleteCeza(String docId) async {
    await _cezalar.doc(docId).delete();
  }

  // --- KESİNTİLER API ---
  CollectionReference get _kesintiler => _db.collection('kesintiler');

  Stream<QuerySnapshot> getKesintilerStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _kesintiler.where('firma', isEqualTo: firma).snapshots();
    }
    return _kesintiler.snapshots();
  }

  Stream<QuerySnapshot> getAllKesintilerStream() {
    return _kesintiler.snapshots();
  }

  Future<void> addKesinti(Map<String, dynamic> kesintiData) async {
    kesintiData['timestamp'] ??= FieldValue.serverTimestamp();
    await _kesintiler.add(kesintiData);
  }

  Future<void> deleteKesinti(String docId) async {
    await _kesintiler.doc(docId).delete();
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getCompanies() async {
    final snap = await _db.collection('firmalar').get();
    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
  }

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _users.doc(uid).set(data);

    // If the registered user is a producer (uretici), sync to ureticiler collection
    if (data['role'] == 'uretici') {
      final phone = data['phone'] as String? ?? '';
      final query = await _producers.where('phone', isEqualTo: phone).limit(1).get();

      final String? selectedFirma = data['firmaName'] as String?;
      final List<String> initialFirmalar = selectedFirma != null && selectedFirma.isNotEmpty
          ? [selectedFirma]
          : [];

      if (query.docs.isEmpty) {
        await _producers.add({
          'name': data['displayName'] ?? data['name'] ?? '',
          'phone': phone,
          'group': data['mahalleKoy'] ?? '',
          'bolge': data['ilce'] ?? '',
          'total': 0.0,
          'avg': 30.0,
          'firmalar': initialFirmalar
        });
      } else {
        final docRef = query.docs.first.reference;
        final docData = query.docs.first.data() as Map<String, dynamic>;
        final List<String> existingFirmalar = List<String>.from(docData['firmalar'] ?? []);
        if (selectedFirma != null && selectedFirma.isNotEmpty) {
          if (!existingFirmalar.contains(selectedFirma)) {
            existingFirmalar.add(selectedFirma);
          }
        }
        await docRef.update({
          'name': data['displayName'] ?? data['name'] ?? '',
          'group': data['mahalleKoy'] ?? '',
          'bolge': data['ilce'] ?? '',
          'firmalar': existingFirmalar,
        });

        // Auto-match user's company profile
        if ((selectedFirma == null || selectedFirma.isEmpty) && existingFirmalar.isNotEmpty) {
          final matchedFirmaName = existingFirmalar.first;
          String matchedFirmaId = '';
          final fQuery = await _db.collection('firmalar').where('ad', isEqualTo: matchedFirmaName).limit(1).get();
          if (fQuery.docs.isNotEmpty) {
            matchedFirmaId = fQuery.docs.first.id;
          }
          data['firmaName'] = matchedFirmaName;
          data['firmaId'] = matchedFirmaId;
          await _users.doc(uid).update({
            'firmaName': matchedFirmaName,
            'firmaId': matchedFirmaId,
          });
        }
      }
    }
  }

  // --- NOTIFICATIONS API ---
  CollectionReference get _bildirimler => _db.collection('bildirimler');

  Stream<QuerySnapshot> getNotificationsStream(String userId) {
    return _bildirimler
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> sendNotification({
    required String recipientName,
    required String role,
    required String baslik,
    required String icerik,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    // 1. Search for recipient in 'users' collection to get their UID
    String? uid;
    final userQuery = await getQueryWithCachePriority(
      _users.where('displayName', isEqualTo: recipientName).where('role', isEqualTo: role).limit(1)
    );

    if (userQuery.docs.isNotEmpty) {
      uid = userQuery.docs.first.id;
    } else {
      // Fallback to generate demo UID
      uid = 'demo_${role}_${recipientName.hashCode}';
    }

    // 2. Check if notification type is enabled for this user
    bool isEnabled = true;
    final doc = await getDocWithCachePriority(_users.doc(uid));
    if (doc.exists) {
      final userData = doc.data() as Map<String, dynamic>?;
      if (userData != null && userData.containsKey('notificationSettings')) {
        final settings = userData['notificationSettings'] as Map<String, dynamic>?;
        if (settings != null && settings.containsKey(type)) {
          isEnabled = settings[type] as bool? ?? true;
        }
      }
    }

    if (!isEnabled) return;

    // 3. Write notification
    await _bildirimler.add({
      'userId': uid,
      'baslik': baslik,
      'icerik': icerik,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'type': type,
      if (extraData != null) ...extraData,
    });
  }

  Future<void> markNotificationRead(String docId) async {
    await _bildirimler.doc(docId).update({'read': true});
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final query = await _bildirimler.where('userId', isEqualTo: userId).where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (var doc in query.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> clearAllNotifications(String userId) async {
    final query = await _bildirimler.where('userId', isEqualTo: userId).get();
    final batch = _db.batch();
    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> updateNotificationSettings(String userId, Map<String, bool> settings) async {
    await _users.doc(userId).set({
      'notificationSettings': settings,
    }, SetOptions(merge: true));
  }

  Future<void> sendAnnouncement({
    required String senderId,
    required String senderFirma,
    required String baslik,
    required String icerik,
    required bool targetDrivers,
    required bool targetProducers,
    required bool isGlobal,
    List<String>? targetRoles,
    bool isPopUp = false,
    String? imageUrl,
  }) async {
    if (!isGlobal) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      
      final allAnnouncements = await _db.collection('duyurular')
          .where('senderFirma', isEqualTo: senderFirma)
          .get();

      final todayDocs = allAnnouncements.docs.where((doc) {
        final data = doc.data();
        final tsVal = data['timestamp'];
        final timestamp = tsVal is Timestamp ? tsVal : null;
        if (timestamp == null) return false;
        final date = timestamp.toDate();
        return date.isAfter(startOfToday) || date.isAtSameMomentAs(startOfToday);
      }).toList();

      if (todayDocs.length >= 3) {
        throw Exception('Günlük duyuru gönderme limitine (3 adet) ulaştınız.');
      }
    }

    final List<String> recipients = [];

    if (isGlobal) {
      final usersSnap = await _users.get();
      for (var doc in usersSnap.docs) {
        final udata = doc.data() as Map<String, dynamic>?;
        if (udata != null) {
          final roleStr = udata['role'] as String? ?? '';
          if (targetRoles == null || targetRoles.contains(roleStr)) {
            recipients.add(doc.id);
          }
        }
      }

      // Add demo recipients globally
      if (targetRoles == null || targetRoles.contains('admin')) {
        recipients.add('demo_admin');
      }
      if (targetRoles == null || targetRoles.contains('firma')) {
        recipients.add('demo_firma_${'Kayseri Çiftlik'.hashCode}');
        recipients.add('demo_firma_${'Sivas Süt A.Ş.'.hashCode}');
      }
      if (targetRoles == null || targetRoles.contains('surucu')) {
        recipients.add('demo_surucu_${'Ahmet Kara'.hashCode}');
        recipients.add('demo_surucu_${'Veli Yıldız'.hashCode}');
      }
      if (targetRoles == null || targetRoles.contains('uretici')) {
        recipients.add('demo_uretici_${'Mehmet Yılmaz'.hashCode}');
        recipients.add('demo_uretici_${'Fatma Korkmaz'.hashCode}');
        recipients.add('demo_uretici_${'Ali Özdemir'.hashCode}');
        recipients.add('demo_uretici_${'Ayşe Şahin'.hashCode}');
        recipients.add('demo_uretici_${'Hüseyin Kaya'.hashCode}');
      }
    } else {
      final usersSnap = await _users.get();
      for (var doc in usersSnap.docs) {
        final udata = doc.data() as Map<String, dynamic>?;
        if (udata != null) {
          final uFirma = udata['firmaName'] as String? ?? udata['firmaId'] as String? ?? '';
          if (uFirma == senderFirma) {
            final roleStr = udata['role'] as String? ?? '';
            if (roleStr == 'surucu' && targetDrivers) {
              recipients.add(doc.id);
            } else if (roleStr == 'uretici' && targetProducers) {
              recipients.add(doc.id);
            }
          }
        }
      }

      // Add demo recipients for the specific company
      if (senderFirma == 'Kayseri Çiftlik') {
        if (targetDrivers) {
          recipients.add('demo_surucu_${'Ahmet Kara'.hashCode}');
        }
        if (targetProducers) {
          recipients.add('demo_uretici_${'Mehmet Yılmaz'.hashCode}');
          recipients.add('demo_uretici_${'Fatma Korkmaz'.hashCode}');
          recipients.add('demo_uretici_${'Ali Özdemir'.hashCode}');
        }
      } else if (senderFirma == 'Sivas Süt A.Ş.') {
        if (targetDrivers) {
          recipients.add('demo_surucu_${'Veli Yıldız'.hashCode}');
        }
        if (targetProducers) {
          recipients.add('demo_uretici_${'Ayşe Şahin'.hashCode}');
          recipients.add('demo_uretici_${'Hüseyin Kaya'.hashCode}');
        }
      }
    }

    final uniqueRecipients = recipients.toSet().toList();
    final type = isGlobal ? 'admin_bildirim' : 'firma_bildirim';
    final batch = _db.batch();

    int iletilenCount = 0;
    int iletilemeyenCount = 0;

    for (var rId in uniqueRecipients) {
      bool isEnabled = true;
      final doc = await _users.doc(rId).get();
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>?;
        if (userData != null && userData.containsKey('notificationSettings')) {
          final settings = userData['notificationSettings'] as Map<String, dynamic>?;
          if (settings != null && settings.containsKey(type)) {
            isEnabled = settings[type] as bool? ?? true;
          }
        }
      }

      if (isEnabled) {
        iletilenCount++;
        final docRef = _bildirimler.doc();
        batch.set(docRef, {
          'userId': rId,
          'baslik': baslik,
          'icerik': icerik,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': type,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        });
      } else {
        iletilemeyenCount++;
      }
    }
    await batch.commit();

    await _db.collection('duyurular').add({
      'senderId': senderId,
      'senderFirma': senderFirma,
      'baslik': baslik,
      'icerik': icerik,
      'timestamp': FieldValue.serverTimestamp(),
      'targetDrivers': targetDrivers,
      'targetProducers': targetProducers,
      'isGlobal': isGlobal,
      'targetRoles': targetRoles,
      'isPopUp': isPopUp,
      'iletilenCount': iletilenCount,
      'iletilemeyenCount': iletilemeyenCount,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });
  }

  // --- COMMON FINANCIAL LEDGER HELPERS ---

  String mapMilkTypeToPriceKey(String type) {
    switch (type.toLowerCase()) {
      case 'sıcak süt':
      case 'sıcak':
      case 'b kalite':
        return 'sicak';
      case 'So\u011fuk S\u00fct':
      case 'soğuk':
      case 'a kalite':
        return 'soguk';
      case 'c kalite':
        return 'c_kalite';
      case 'd kalite':
        return 'd_kalite';
      default:
        return 'soguk';
    }
  }

  double resolveMilkPrice({
    required List<Map<String, dynamic>> prices,
    required String producerName,
    required String bolge,
    required String group,
    required String type,
  }) {
    // 1. Üretici Özel
    final uPrice = prices.firstWhere(
      (p) => p['tip'] == 'uretici' && p['hedef'] == producerName,
      orElse: () => <String, dynamic>{},
    );
    if (uPrice.isNotEmpty && uPrice['fiyatlar']?[type] != null) {
      return (uPrice['fiyatlar'][type] as num).toDouble();
    }

    // 2. Bölge Özel
    if (bolge.isNotEmpty) {
      final bPrice = prices.firstWhere(
        (p) => p['tip'] == 'bolge' && p['hedef'] == bolge,
        orElse: () => <String, dynamic>{},
      );
      if (bPrice.isNotEmpty && bPrice['fiyatlar']?[type] != null) {
        return (bPrice['fiyatlar'][type] as num).toDouble();
      }
    }

    // 3. Grup Özel
    if (group.isNotEmpty) {
      final gPrice = prices.firstWhere(
        (p) => p['tip'] == 'grup' && p['hedef'] == group,
        orElse: () => <String, dynamic>{},
      );
      if (gPrice.isNotEmpty && gPrice['fiyatlar']?[type] != null) {
        return (gPrice['fiyatlar'][type] as num).toDouble();
      }
    }

    // 4. Genel
    final genPrice = prices.firstWhere(
      (p) => p['tip'] == 'genel',
      orElse: () => <String, dynamic>{},
    );
    if (genPrice.isNotEmpty && genPrice['fiyatlar']?[type] != null) {
      return (genPrice['fiyatlar'][type] as num).toDouble();
    }

    return 23.0; // Fallback default milk price
  }

  Map<String, dynamic> calculateLedger({
    required List<QueryDocumentSnapshot> collections,
    required List<QueryDocumentSnapshot> prices,
    required List<QueryDocumentSnapshot> tahsilatlar,
    required List<QueryDocumentSnapshot> avanslar,
    required List<QueryDocumentSnapshot> kesintiler,
    required List<QueryDocumentSnapshot> cezalar,
    List<QueryDocumentSnapshot>? devirler,
    List<QueryDocumentSnapshot>? satislar,
    required String producerName,
    required String bolge,
    required String group,
    Map<String, dynamic>? kesintiAyarlari,
    List<String>? dynamicColumns,
    double? bagkurOran,
    double? stopajOran,
    double? borsaOran,
  }) {
    final priceList = prices.map((d) => d.data() as Map<String, dynamic>).toList();

    // 1. Calculate Gross Milk Receivable
    double toplamAlacak = 0.0;
    double toplamLitre = 0.0;
    double dynamicKesintiSum = 0.0;

    // Resolve deduction settings schedule
    final Map<String, dynamic> activeSchedule = {};
    final List<String> activeCols = dynamicColumns ?? ['Bağkur', 'Stopaj', 'Borsa'];
    final double defaultBagkur = bagkurOran ?? 2.10;
    final double defaultStopaj = stopajOran ?? 1.00;
    final double defaultBorsa = borsaOran ?? 0.20;

    for (var type in activeCols) {
      if (kesintiAyarlari != null && kesintiAyarlari.containsKey(type)) {
        final s = kesintiAyarlari[type];
        if (s is Map) {
          activeSchedule[type] = {
            'oran': (s['oran'] as num?)?.toDouble() ?? 0.0,
            'aktif': s['aktif'] == true,
            'baslangic': s['baslangic'] as String?,
            'bitis': s['bitis'] as String?,
          };
        }
      } else {
        double rate = 0.0;
        if (type == 'Bağkur') rate = defaultBagkur;
        else if (type == 'Stopaj') rate = defaultStopaj;
        else if (type == 'Borsa') rate = defaultBorsa;

        activeSchedule[type] = {
          'oran': rate,
          'aktif': true,
          'baslangic': null,
          'bitis': null,
        };
      }
    }

    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final mVal = data['m'];
      final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
      toplamLitre += m;

      final String rawType = data['tip'] ?? 'So\u011fuk S\u00fct';
      final String priceKey = mapMilkTypeToPriceKey(rawType);
      final double price = resolveMilkPrice(
        prices: priceList,
        producerName: producerName,
        bolge: bolge,
        group: group,
        type: priceKey,
      );
      final double colVal = m * price;
      toplamAlacak += colVal;

      // Resolve collection date
      DateTime colDate = DateTime.now();
      final tsVal = data['timestamp'];
      final Timestamp? ts = tsVal is Timestamp ? tsVal : null;
      if (ts != null) {
        colDate = ts.toDate();
      } else {
        final dateStr = data['tarih'] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          try {
            final parts = dateStr.split('.');
            colDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          } catch (_) {}
        }
      }

      // Calculate dynamic deductions for this collection
      activeSchedule.forEach((name, settings) {
        if (settings['aktif'] == true) {
          bool isInRange = true;
          final baslangicStr = settings['baslangic'] as String?;
          final bitisStr = settings['bitis'] as String?;

          DateTime parseDate(String s) {
            if (s.contains('-')) {
              return DateTime.parse(s);
            } else {
              final parts = s.split('.');
              return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          }

          if (baslangicStr != null && baslangicStr.isNotEmpty) {
            try {
              final start = parseDate(baslangicStr);
              final cOnly = DateTime(colDate.year, colDate.month, colDate.day);
              final sOnly = DateTime(start.year, start.month, start.day);
              if (cOnly.isBefore(sOnly)) isInRange = false;
            } catch (_) {}
          }

          if (bitisStr != null && bitisStr.isNotEmpty) {
            try {
              final end = parseDate(bitisStr);
              final cOnly = DateTime(colDate.year, colDate.month, colDate.day);
              final eOnly = DateTime(end.year, end.month, end.day);
              if (cOnly.isAfter(eOnly)) isInRange = false;
            } catch (_) {}
          }

          if (isInRange) {
            final double oran = (settings['oran'] as num?)?.toDouble() ?? 0.0;
            dynamicKesintiSum += colVal * (oran / 100.0);
          }
        }
      });
    }

    // 2. Total Payments (Odeme) & Collections (Tahsilat)
    double totalTahsilat = 0.0; // payments made by company to producer (called totalOdeme but keep return key as totalTahsilat for UI compatibility)
    double totalProducerTahsilat = 0.0; // payments made by producer to company (actual collection)
    for (var doc in tahsilatlar) {
      final data = doc.data() as Map<String, dynamic>;
      final tVal = data['tutar'];
      final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
      final type = getTahsilatType(data);
      if (type == 'tahsilat') {
        totalProducerTahsilat += val;
      } else {
        totalTahsilat += val;
      }
    }

    // 3. Active Advances (Avans)
    double totalAvans = 0.0;
    for (var doc in avanslar) {
      final data = doc.data() as Map<String, dynamic>;
      final durum = data['durum'] ?? 'aktif';
      if (durum == 'aktif') {
        final aVal = data['tutar'];
        totalAvans += aVal is num ? aVal.toDouble() : (double.tryParse(aVal.toString()) ?? 0.0);
      }
    }

    // 4. Active Deductions (Kesinti)
    // We ignore manual kesintiler collection documents as they are double-deductions of product sales (satislar)
    double totalManualKesinti = 0.0;

    // 5. Active Penalties (Ceza)
    double totalCeza = 0.0;
    for (var doc in cezalar) {
      final data = doc.data() as Map<String, dynamic>;
      final durum = data['durum'] ?? 'aktif';
      if (durum == 'aktif') {
        final tip = data['tip'] ?? 'miktarsal';
        if (tip == 'oransal') {
          final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
          totalCeza += toplamAlacak * (oran / 100.0);
        } else {
          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
          totalCeza += tutar;
        }
      }
    }

    // 5b. Active Sales (Satislar)
    double totalSales = 0.0;
    if (satislar != null) {
      for (var doc in satislar) {
        final data = doc.data() as Map<String, dynamic>;
        final sVal = data['tutar'];
        totalSales += sVal is num ? sVal.toDouble() : (double.tryParse(sVal.toString()) ?? 0.0);
      }
    }

    // 6. Devir/Düzeltme (Carryover balance)
    double totalDevir = 0.0;
    if (devirler != null) {
      for (var doc in devirler) {
        final data = doc.data() as Map<String, dynamic>;
        final dVal = data['tutar'];
        totalDevir += dVal is num ? dVal.toDouble() : (double.tryParse(dVal.toString()) ?? 0.0);
      }
    }

    final double totalKesinti = totalManualKesinti + dynamicKesintiSum;

    // Net balance = gross milk receivable - payments - active advances - active kesintiler - active cezalar - active sales + devirler + collections from producer
    final double netBalance = toplamAlacak - totalTahsilat - totalAvans - totalKesinti - totalCeza - totalSales + totalDevir + totalProducerTahsilat;

    return {
      'toplamLitre': toplamLitre,
      'toplamAlacak': toplamAlacak,
      'totalTahsilat': totalTahsilat,
      'totalProducerTahsilat': totalProducerTahsilat,
      'totalAvans': totalAvans,
      'totalKesinti': totalKesinti,
      'totalCeza': totalCeza,
      'totalDevir': totalDevir,
      'totalSales': totalSales,
      'netBalance': netBalance,
    };
  }
}


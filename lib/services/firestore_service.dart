import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _tanks => _db.collection('tanklar');
  CollectionReference get _drivers => _db.collection('suruculer');
  CollectionReference get _vehicles => _db.collection('araclar');
  CollectionReference get _producers => _db.collection('ureticiler');
  CollectionReference get _collections => _db.collection('toplamalar');

  CollectionReference get _teslimatlar => _db.collection('teslimatlar');
  CollectionReference get _tahsilatlar => _db.collection('tahsilatlar');
  CollectionReference get _users => _db.collection('users');

  Future<void> _clearCollection(CollectionReference ref) async {
    final snap = await ref.get();
    for (var doc in snap.docs) {
      await doc.reference.delete();
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
    } catch (e) {
      print('Mock initialization error: $e');
    }
  }

  // --- TANKS API ---
  Stream<QuerySnapshot> getTanksStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _tanks.where('firma', isEqualTo: firma).snapshots();
    }
    return _tanks.snapshots();
  }

  Future<void> addTank(Map<String, dynamic> tank) async {
    await _tanks.add(tank);
  }

  // --- DRIVERS API ---
  Stream<QuerySnapshot> getDriversStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _drivers.where('firma', isEqualTo: firma).snapshots();
    }
    return _drivers.snapshots();
  }

  Future<void> addDriver(Map<String, dynamic> driver) async {
    await _drivers.add(driver);
  }

  // --- VEHICLES API ---
  Stream<QuerySnapshot> getVehiclesStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _vehicles.where('firma', isEqualTo: firma).snapshots();
    }
    return _vehicles.snapshots();
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
    return _producers.snapshots();
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
      await _producers.add(data);
    }
  }

  // --- COLLECTIONS API ---
  Stream<QuerySnapshot> getCollectionsStream({String? firma}) {
    if (firma != null && firma.isNotEmpty) {
      return _collections.where('firma', isEqualTo: firma).snapshots();
    }
    return _collections.snapshots();
  }

  Future<void> addCollection(Map<String, dynamic> collection) async {
    collection['timestamp'] = FieldValue.serverTimestamp();
    await _collections.add(collection);
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
    // Resolve company name if not explicitly passed
    String resolvedFirma = firma ?? '';
    if (resolvedFirma.isEmpty) {
      final tankQuery = await _tanks.where('ad', isEqualTo: tankName).limit(1).get();
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
      'timestamp': customDate != null ? Timestamp.fromDate(customDate) : FieldValue.serverTimestamp(),
      'firma': resolvedFirma,
      'tip': sutTipi ?? 'Soğuk süt',
      'customerType': customerType ?? 'sut',
      'vakit': (vakit != null && vakit.isNotEmpty)
          ? vakit
          : ((targetDate.hour >= 2 && targetDate.hour < 14) ? 'Sabah' : 'Akşam'),
      if (kalite != null) 'kalite': kalite,
    });

    // 2. Update tank stock in tanklar collection
    final tankQuery = await _tanks.where('ad', isEqualTo: tankName).limit(1).get();
    if (tankQuery.docs.isNotEmpty) {
      final tankDoc = tankQuery.docs.first;
      final currentStock = (tankDoc['stok'] as num).toDouble();
      final newStock = (currentStock + miktar).clamp(0.0, double.infinity);
      await tankDoc.reference.update({'stok': newStock});

      // 3. If it's a vehicle tank, update in the vehicle document as well
      if (tankDoc['tip'] == 'arac') {
        final plate = tankDoc['arac'] as String;
        if (plate.isNotEmpty) {
          final vehicleQuery = await _vehicles.where('plaka', isEqualTo: plate).limit(1).get();
          if (vehicleQuery.docs.isNotEmpty) {
            final vehicleDoc = vehicleQuery.docs.first;
            final List<dynamic> vehicleTanks = (vehicleDoc['tanklar'] as List? ?? [])
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

    // 4. Update producer total milk & last milk type preference
    final prodQuery = await _producers.where('name', isEqualTo: producerName).limit(1).get();
    if (prodQuery.docs.isNotEmpty) {
      final prodDoc = prodQuery.docs.first;
      final currentTotal = (prodDoc['total'] as num).toDouble();
      final newTotal = currentTotal + miktar;
      await prodDoc.reference.update({
        'total': newTotal,
        'lastMilkType': sutTipi ?? 'Soğuk Süt',
      });
    }

    // 5. Send notification to the producer
    if (notifyProducer) {
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

    // 1. Subtract from tank stock
    if (tankName.isNotEmpty) {
      final tankQuery = await _tanks.where('ad', isEqualTo: tankName).limit(1).get();
      if (tankQuery.docs.isNotEmpty) {
        final tankDoc = tankQuery.docs.first;
        final currentStock = (tankDoc['stok'] as num).toDouble();
        final newStock = (currentStock - miktar).clamp(0.0, double.infinity);
        await tankDoc.reference.update({'stok': newStock});

        // Update in vehicle document as well
        if (tankDoc['tip'] == 'arac' && vehiclePlate.isNotEmpty) {
          final vehicleQuery = await _vehicles.where('plaka', isEqualTo: vehiclePlate).limit(1).get();
          if (vehicleQuery.docs.isNotEmpty) {
            final vehicleDoc = vehicleQuery.docs.first;
            final List<dynamic> vehicleTanks = (vehicleDoc['tanklar'] as List? ?? [])
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
            final List<dynamic> vehicleTanks = (vehicleDoc['tanklar'] as List? ?? [])
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
        final List<dynamic> vehicleTanks = (vehicleDoc['tanklar'] as List? ?? [])
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
        final List<dynamic> driversList = vehicleDoc['suruculer'] as List? ?? [];
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
    required double miktar,
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

    // 1. Update source tank stok
    final double sourceCurrent = (sourceDoc.data()['stok'] as num?)?.toDouble() ?? 0.0;
    await sourceDoc.reference.update({'stok': (sourceCurrent - miktar).clamp(0.0, double.infinity)});

    // 2. Update target tank stok
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
        final List<dynamic> vehicleTanks = (vehicleDoc['tanklar'] as List? ?? [])
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        for (int i = 0; i < vehicleTanks.length; i++) {
          if (vehicleTanks[i]['ad'] == sourceTankName) {
            vehicleTanks[i]['stok'] = (sourceCurrent - miktar).clamp(0.0, double.infinity);
            break;
          }
        }
        await vehicleDoc.reference.update({'tanklar': vehicleTanks});
      }
    }

    // 4. Update sut_kabul document state
    await kabulDocRef.update({'durum': 'Kabul Edildi'});

    // 5. Also log a delivery record to 'teslimatlar' for audit
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    await db.collection('teslimatlar').add({
      'plaka': vehiclePlate,
      'kaynakTank': sourceTankName,
      'hedefTank': targetTankName,
      'miktar': miktar,
      'saat': timeStr,
      'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
      'timestamp': FieldValue.serverTimestamp(),
      'firma': targetDoc.data()['firma'] ?? '',
    });

    // 6. Send success notification to the driver
    try {
      await sendNotification(
        recipientName: driverName,
        role: 'surucu',
        baslik: 'Boşaltma Talebi Onaylandı',
        icerik: '$sourceTankName tankından $targetTankName tankına $miktar LT boşaltma işleminiz onaylandı.',
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

  Future<void> recordTahsilat({
    required String producerName,
    required double tutar,
    String? odemeYontemi,
    String? aciklama,
    String? firma,
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

    await _db.collection('tahsilatlar').add({
      'uretici': producerName,
      'tutar': tutar,
      'odemeYontemi': odemeYontemi ?? 'Nakit',
      'aciklama': aciklama ?? '',
      'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
      'saat': DateFormat('HH:mm').format(DateTime.now()),
      'timestamp': FieldValue.serverTimestamp(),
      'firma': resolvedFirma,
    });
  }

  // --- DRIVER SPECIFIC STREAMS ---

  Stream<QuerySnapshot> getDriverVehicleStream(String driverName) {
    return _vehicles.where('suruculer', arrayContains: driverName).limit(1).snapshots();
  }

  Stream<QuerySnapshot> getDriverCollectionsStream(String driverName) {
    return _collections.where('sr', isEqualTo: driverName).snapshots();
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
    avansData['timestamp'] = FieldValue.serverTimestamp();
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
    cezaData['timestamp'] = FieldValue.serverTimestamp();
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
    kesintiData['timestamp'] = FieldValue.serverTimestamp();
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
  }) async {
    // 1. Search for recipient in 'users' collection to get their UID
    String? uid;
    final userQuery = await _users
        .where('displayName', isEqualTo: recipientName)
        .where('role', isEqualTo: role)
        .limit(1)
        .get();

    if (userQuery.docs.isNotEmpty) {
      uid = userQuery.docs.first.id;
    } else {
      // Fallback to generate demo UID
      uid = 'demo_${role}_${recipientName.hashCode}';
    }

    // 2. Check if notification type is enabled for this user
    bool isEnabled = true;
    final doc = await _users.doc(uid).get();
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
  }) async {
    if (!isGlobal) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      
      final todayAnnouncements = await _db.collection('duyurular')
          .where('senderFirma', isEqualTo: senderFirma)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      if (todayAnnouncements.docs.length >= 3) {
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
    });
  }

  // --- COMMON FINANCIAL LEDGER HELPERS ---

  String mapMilkTypeToPriceKey(String type) {
    switch (type.toLowerCase()) {
      case 'sıcak süt':
      case 'sıcak':
      case 'b kalite':
        return 'sicak';
      case 'soğuk süt':
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
    required String producerName,
    required String bolge,
    required String group,
    Map<String, dynamic>? kesintiAyarlari,
  }) {
    final priceList = prices.map((d) => d.data() as Map<String, dynamic>).toList();

    // 1. Calculate Gross Milk Receivable
    double toplamAlacak = 0.0;
    double toplamLitre = 0.0;
    double dynamicKesintiSum = 0.0;

    // Resolve deduction settings schedule
    final Map<String, dynamic> activeSchedule = {};
    final defaultRates = {
      'Bağkur': 2.10,
      'Stopaj': 1.00,
      'Borsa': 0.20,
    };

    if (kesintiAyarlari != null && kesintiAyarlari.isNotEmpty) {
      kesintiAyarlari.forEach((key, val) {
        if (val is Map) {
          activeSchedule[key] = Map<String, dynamic>.from(val);
        }
      });
    } else {
      defaultRates.forEach((key, val) {
        activeSchedule[key] = {
          'oran': val,
          'aktif': true,
          'baslangic': null,
          'bitis': null,
        };
      });
    }

    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final mVal = data['m'];
      final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
      toplamLitre += m;

      final String rawType = data['tip'] ?? 'Soğuk süt';
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
      final ts = data['timestamp'] as Timestamp?;
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

    // 2. Total Payments (Tahsilat)
    double totalTahsilat = 0.0;
    for (var doc in tahsilatlar) {
      final data = doc.data() as Map<String, dynamic>;
      final tVal = data['tutar'];
      totalTahsilat += tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
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
    double totalManualKesinti = 0.0;
    for (var doc in kesintiler) {
      final data = doc.data() as Map<String, dynamic>;
      final durum = data['durum'] ?? 'aktif';
      if (durum == 'aktif') {
        final kVal = data['tutar'];
        totalManualKesinti += kVal is num ? kVal.toDouble() : (double.tryParse(kVal.toString()) ?? 0.0);
      }
    }

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

    // Net balance = gross milk receivable - payments - active advances - active kesintiler - active cezalar + devirler
    final double netBalance = toplamAlacak - totalTahsilat - totalAvans - totalKesinti - totalCeza + totalDevir;

    return {
      'toplamLitre': toplamLitre,
      'toplamAlacak': toplamAlacak,
      'totalTahsilat': totalTahsilat,
      'totalAvans': totalAvans,
      'totalKesinti': totalKesinti,
      'totalCeza': totalCeza,
      'totalDevir': totalDevir,
      'netBalance': netBalance,
    };
  }
}


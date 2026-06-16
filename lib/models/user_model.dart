enum UserRole { admin, firma, surucu, uretici }

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final String? firmaId;
  final String? firmaName;
  final String? phone;
  final String? il;
  final String? ilce;
  final String? mahalleKoy;
  final String? adresDetay;
  final String? postaKodu;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.firmaId,
    this.firmaName,
    this.phone,
    this.il,
    this.ilce,
    this.mahalleKoy,
    this.adresDetay,
    this.postaKodu,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    UserRole parsedRole = UserRole.uretici;
    if (data['role'] != null) {
      final roleStr = data['role'] as String;
      parsedRole = UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.uretici,
      );
    }
    return AppUser(
      uid: uid,
      displayName: data['displayName'] ?? data['name'] ?? '',
      email: data['email'] ?? '',
      role: parsedRole,
      firmaId: data['firmaId'],
      firmaName: data['firmaName'],
      phone: data['phone'],
      il: data['il'],
      ilce: data['ilce'],
      mahalleKoy: data['mahalleKoy'] ?? data['group'] ?? '',
      adresDetay: data['adresDetay'] ?? '',
      postaKodu: data['postaKodu'] ?? '',
    );
  }

  factory AppUser.demo(UserRole role) {
    final configs = {
      UserRole.admin: {'name': 'Admin Kullanıcı', 'email': 'admin@sutapp.com', 'phone': '0532 000 0001'},
      UserRole.firma: {'name': 'Kayseri Çiftlik', 'email': 'firma@sutapp.com', 'phone': '0532 000 0002'},
      UserRole.surucu: {'name': 'Ahmet Kara', 'email': 'surucu@sutapp.com', 'phone': '0532 000 0003'},
      UserRole.uretici: {'name': 'Mehmet Yılmaz', 'email': 'uretici@sutapp.com', 'phone': '0532 000 0004'},
    };
    final c = configs[role]!;
    return AppUser(
      uid: 'demo_${role.name}',
      displayName: c['name']!,
      email: c['email']!,
      role: role,
      firmaId: role == UserRole.admin ? null : 'demo_firma_1',
      firmaName: role == UserRole.admin ? null : 'Kayseri Çiftlik',
      phone: c['phone']!,
      il: 'Kayseri',
      ilce: 'Kocasinan',
      mahalleKoy: 'Yayla Çiftliği',
      adresDetay: 'Yayla Mahallesi No:5',
      postaKodu: '38000',
    );
  }

  String get roleName {
    switch (role) {
      case UserRole.admin: return 'Sistem Admini';
      case UserRole.firma: return 'Firma Yöneticisi';
      case UserRole.surucu: return 'Toplayıcı';
      case UserRole.uretici: return 'Süt Üreticisi';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'name': displayName,
      'email': email,
      'role': role.name,
      'firmaId': firmaId,
      'firmaName': firmaName,
      'phone': phone,
      'il': il,
      'ilce': ilce,
      'mahalleKoy': mahalleKoy,
      'group': mahalleKoy,
      'adresDetay': adresDetay,
      'postaKodu': postaKodu,
    };
  }
}


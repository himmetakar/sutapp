import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/location_picker_field.dart';

class SurucuUreticilerScreen extends StatefulWidget {
  final bool openAddDialog;
  const SurucuUreticilerScreen({super.key, this.openAddDialog = false});

  @override
  State<SurucuUreticilerScreen> createState() => _SurucuUreticilerScreenState();
}

class _SurucuUreticilerScreenState extends State<SurucuUreticilerScreen> {
  final _db = FirebaseFirestore.instance;
  final _firestoreService = FirestoreService();

  String _search = '';
  bool _addDialogOpened = false;

  // ─── helpers ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getCurrentDriverInfo(String driverName, String userEmail) async {
    final snap = await _db
        .collection('suruculer')
        .get();
    
    DocumentSnapshot? matchedDoc;
    // Pass 1: match by name
    if (driverName.isNotEmpty) {
      for (var doc in snap.docs) {
        final d = doc.data();
        final fullName = '${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim();
        if (fullName.toLowerCase() == driverName.toLowerCase()) {
          matchedDoc = doc;
          break;
        }
      }
    }
    // Pass 2: match by email
    if (matchedDoc == null && userEmail.isNotEmpty) {
      for (var doc in snap.docs) {
        final d = doc.data();
        final email = d['email'] ?? '';
        if (email.isNotEmpty && email == userEmail) {
          matchedDoc = doc;
          break;
        }
      }
    }

    if (matchedDoc != null) {
      final d = matchedDoc.data() as Map<String, dynamic>;
      return {
        'firma': d['firma'] ?? '',
        'canAddCustomer': d['canAddCustomer'] ?? true,
        'canEditCustomer': d['canEditCustomer'] ?? true,
      };
    }
    return {
      'firma': '',
      'canAddCustomer': true,
      'canEditCustomer': true,
    };
  }

  // Returns pending teklifler for this toplayıcı keyed by ureticiId
  Map<String, Map<String, dynamic>> _buildPendingMap(List<QueryDocumentSnapshot> teklifDocs) {
    final Map<String, Map<String, dynamic>> map = {};
    for (var d in teklifDocs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['durum'] == 'beklemede') {
        final id = data['ureticiId'] as String? ?? d.id; // ekle → use doc id
        map[id] = {...data, '_id': d.id};
      }
    }
    return map;
  }

  // ─── Proposal creation ─────────────────────────────────────────────────────

  Future<void> _submitRequest({
    required String tip,
    required String toplayici,
    required String firma,
    Map<String, dynamic>? yeniData,
    Map<String, dynamic>? eskiData,
    String? ureticiId,
  }) async {
    final docRef = await _db.collection('toplayici_teklifleri').add({
      'tip': tip,
      'toplayici': toplayici,
      'firma': firma,
      'durum': 'beklemede',
      if (yeniData != null) 'yeniData': yeniData,
      if (eskiData != null) 'eskiData': eskiData,
      if (ureticiId != null) 'ureticiId': ureticiId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final tipLabel = tip == 'ekle'
        ? 'Yeni Üretici Ekleme'
        : tip == 'duzenle'
            ? 'Üretici Düzenleme'
            : 'Üretici Silme';

    final ureticiAd = yeniData?['name'] ?? eskiData?['name'] ?? '—';
    await _firestoreService.sendNotification(
      recipientName: firma,
      role: 'firma',
      baslik: 'Toplayıcı Talebi: $tipLabel',
      icerik: '$toplayici → $ureticiAd için $tipLabel talebi oluşturuldu. Onay bekleniyor.',
      type: 'toplayici_talebi',
      extraData: {
        'teklifId': docRef.id,
      },
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  void _showAddDialog(BuildContext context, String toplayici, String firma) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    // Location state
    List<Map<String, dynamic>> provinces = [];
    List<Map<String, dynamic>> districts = [];
    List<Map<String, dynamic>> neighborhoods = [];
    Map<String, dynamic>? selectedProvince;
    Map<String, dynamic>? selectedDistrict;
    Map<String, dynamic>? selectedNeighborhood;
    final manualCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    bool loading = false;
    String selectedMilkType = 'Soğuk Süt';
    bool isYem = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> loadProvinces() async {
            setState(() => loading = true);
            try {
              final client = HttpClient();
              final req = await client.getUrl(Uri.parse('https://turkiyeapi.dev/api/v1/provinces?fields=id,name'));
              final res = await req.close();
              if (res.statusCode == 200) {
                final body = await res.transform(utf8.decoder).join();
                final decoded = jsonDecode(body);
                if (decoded['status'] == 'OK') {
                  final list = List<Map<String, dynamic>>.from(
                    (decoded['data'] as List).map((e) => {'id': e['id'], 'name': e['name']}),
                  );
                  list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                  setState(() { provinces = list; });
                }
              }
              client.close();
            } catch (_) {} finally {
              setState(() => loading = false);
            }
          }

          if (provinces.isEmpty && !loading) Future.microtask(loadProvinces);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Üretici Ekleme Talebi',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Bu talep firma onayına sunulacaktır.',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF856404)))),
                    ]),
                  ),
                  TextField(controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Ad Soyad *', hintText: 'Mustafa Yılmaz')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    decoration: const InputDecoration(
                      labelText: 'Telefon *',
                      hintText: '0532 999 8877',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loading && provinces.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedProvince,
                      hint: const Text('İl Seçiniz'),
                      decoration: const InputDecoration(labelText: 'İl *'),
                      items: provinces.map((p) => DropdownMenuItem(value: p, child: Text(p['name']))).toList(),
                      onChanged: (v) async {
                        setState(() {
                          selectedProvince = v;
                          selectedDistrict = null;
                          selectedNeighborhood = null;
                          districts = [];
                          neighborhoods = [];
                          loading = true;
                        });
                        try {
                          final client = HttpClient();
                          final req = await client.getUrl(Uri.parse('https://turkiyeapi.dev/api/v1/districts?provinceId=${v!['id']}&fields=id,name'));
                          final res = await req.close();
                          if (res.statusCode == 200) {
                            final body = await res.transform(utf8.decoder).join();
                            final decoded = jsonDecode(body);
                            if (decoded['status'] == 'OK') {
                              final list = List<Map<String, dynamic>>.from(
                                (decoded['data'] as List).map((e) => {'id': e['id'], 'name': e['name']}),
                              );
                              list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                              setState(() { districts = list; });
                            }
                          }
                          client.close();
                        } catch (_) {} finally {
                          setState(() => loading = false);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedProvince != null)
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedDistrict,
                        hint: const Text('İlçe Seçiniz'),
                        decoration: const InputDecoration(labelText: 'İlçe *'),
                        items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d['name']))).toList(),
                        onChanged: (v) async {
                          setState(() {
                            selectedDistrict = v;
                            selectedNeighborhood = null;
                            neighborhoods = [];
                            loading = true;
                          });
                          try {
                            final client = HttpClient();
                            final req = await client.getUrl(Uri.parse('https://turkiyeapi.dev/api/v1/neighborhoods?districtId=${v!['id']}&fields=id,name'));
                            final res = await req.close();
                            if (res.statusCode == 200) {
                              final body = await res.transform(utf8.decoder).join();
                              final decoded = jsonDecode(body);
                              if (decoded['status'] == 'OK') {
                                final list = List<Map<String, dynamic>>.from(
                                  (decoded['data'] as List).map((e) => {'id': e['id'], 'name': e['name']}),
                                );
                                list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                                setState(() { neighborhoods = list; });
                              }
                            }
                            client.close();
                          } catch (_) {} finally {
                            setState(() => loading = false);
                          }
                        },
                      ),
                    if (selectedDistrict != null) ...[
                      const SizedBox(height: 12),
                      neighborhoods.isNotEmpty
                          ? DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedNeighborhood,
                              hint: const Text('Mahalle/Köy'),
                              decoration: const InputDecoration(labelText: 'Mahalle / Köy'),
                              items: neighborhoods.map((n) => DropdownMenuItem(value: n, child: Text(n['name']))).toList(),
                              onChanged: (v) => setState(() => selectedNeighborhood = v),
                            )
                          : TextField(controller: manualCtrl,
                              decoration: const InputDecoration(labelText: 'Mahalle / Köy', hintText: 'Akarsu Köyü')),
                    ],
                  ],
                  const SizedBox(height: 12),
                  // Location picker
                  LocationPickerField(
                    latController: latCtrl,
                    lngController: lngCtrl,
                    setDialogState: setState,
                  ),
                  const SizedBox(height: 12),
                  // Süt tipi
                  _MilkTypeSelector(
                    selectedType: selectedMilkType,
                    onChanged: (v) => setState(() => selectedMilkType = v),
                    enabled: !isYem,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text('Yem Müşterisi', style: GoogleFonts.inter(fontSize: 13)),
                    value: isYem,
                    onChanged: (v) => setState(() => isYem = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  final il = selectedProvince?['name'] ?? '';
                  final ilce = selectedDistrict?['name'] ?? '';
                  final mahalle = selectedNeighborhood?['name'] ?? manualCtrl.text.trim();

                  if (name.isEmpty || phone.isEmpty || il.isEmpty || ilce.isEmpty || mahalle.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun.'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  await _submitRequest(
                    tip: 'ekle',
                    toplayici: toplayici,
                    firma: firma,
                    yeniData: {
                      'name': name,
                      'phone': phone,
                      'bolge': ilce,
                      'group': mahalle,
                      'il': il,
                      'firmalar': [firma],
                      'avg': 30.0,
                      'total': 0.0,
                      'lastMilkType': isYem ? 'Yok' : selectedMilkType,
                      'customerType': isYem ? 'yem' : 'sut',
                      if (double.tryParse(latCtrl.text.trim()) != null && double.tryParse(lngCtrl.text.trim()) != null) ...{
                        'latitude': double.tryParse(latCtrl.text.trim()),
                        'longitude': double.tryParse(lngCtrl.text.trim()),
                      } else if (latCtrl.text.trim().isNotEmpty) ...{
                        'mapsLink': latCtrl.text.trim(),
                      },
                    },
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Üretici ekleme talebi firma onayına gönderildi.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Talep Gönder'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String toplayici,
    String firma,
    String ureticiId,
    Map<String, dynamic> currentData,
  ) {
    final nameCtrl = TextEditingController(text: currentData['name'] ?? '');
    final phoneCtrl = TextEditingController(text: currentData['phone'] ?? '');

    // Location controllers initialized with current location data
    final latVal = currentData['latitude'];
    final lngVal = currentData['longitude'];
    final mapsLinkVal = currentData['mapsLink'];

    final latCtrl = TextEditingController(
      text: latVal != null ? latVal.toString() : (mapsLinkVal ?? ''),
    );
    final lngCtrl = TextEditingController(
      text: lngVal != null ? lngVal.toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Üretici Düzenleme Talebi',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Değişiklikler firma onayına sunulacaktır.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF856404)))),
                  ]),
                ),
                TextField(
                  controller: nameCtrl,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Ad Soyad'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                LocationPickerField(
                  latController: latCtrl,
                  lngController: lngCtrl,
                  setDialogState: setState,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                await _submitRequest(
                  tip: 'duzenle',
                  toplayici: toplayici,
                  firma: firma,
                  ureticiId: ureticiId,
                  eskiData: currentData,
                  yeniData: {
                    'name': currentData['name'] ?? '',
                    'phone': phoneCtrl.text.trim(),
                    'bolge': currentData['bolge'] ?? '',
                    'group': currentData['group'] ?? '',
                    'lastMilkType': currentData['lastMilkType'] ?? 'Soğuk Süt',
                    'customerType': currentData['customerType'] ?? 'sut',
                    'latitude': null,
                    'longitude': null,
                    'mapsLink': null,
                    if (double.tryParse(latCtrl.text.trim()) != null && double.tryParse(lngCtrl.text.trim()) != null) ...{
                      'latitude': double.tryParse(latCtrl.text.trim()),
                      'longitude': double.tryParse(lngCtrl.text.trim()),
                    } else if (latCtrl.text.trim().isNotEmpty) ...{
                      'mapsLink': latCtrl.text.trim(),
                    },
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Düzenleme talebi firma onayına gönderildi.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Talep Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    String toplayici,
    String firma,
    String ureticiId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Silme Talebi', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data['name']} üreticisini silmek istiyor musunuz?',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Bu talep firma onayına sunulacak.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF856404)))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await _submitRequest(
                tip: 'sil',
                toplayici: toplayici,
                firma: firma,
                ureticiId: ureticiId,
                eskiData: data,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Silme talebi firma onayına gönderildi.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Talep Gönder'),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final driverName = auth.user?.displayName ?? '';
    final userEmail = auth.user?.email ?? '';

    return FutureBuilder<Map<String, dynamic>>(
      future: _getCurrentDriverInfo(driverName, userEmail),
      builder: (context, infoSnap) {
        final info = infoSnap.data ?? {
          'firma': '',
          'canAddCustomer': true,
          'canEditCustomer': true,
        };
        final firma = info['firma'] ?? '';
        final canAddCustomer = info['canAddCustomer'] ?? true;
        final canEditCustomer = info['canEditCustomer'] ?? true;

        // Auto-open add dialog when coming from '/surucu/ureticiler/ekle'
        if (widget.openAddDialog && firma.isNotEmpty && !_addDialogOpened && canAddCustomer) {
          _addDialogOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showAddDialog(context, driverName, firma);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.gray50,
          appBar: AppBar(
            title: Text('Üreticilerim', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.gray900,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Üretici ara...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: AppColors.gray100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
            ),
            actions: [
              if (firma.isNotEmpty && canAddCustomer)
                IconButton(
                  icon: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary600, shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                  tooltip: 'Üretici Ekle Talebi',
                  onPressed: () => _showAddDialog(context, driverName, firma),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: firma.isEmpty && infoSnap.connectionState == ConnectionState.done
              ? _buildEmptyFirma()
              : firma.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(context, driverName, firma, canEditCustomer),
        );
      },
    );
  }

  Widget _buildEmptyFirma() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.business_rounded, size: 48, color: AppColors.gray300),
        const SizedBox(height: 12),
        Text('Firmanız bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 14)),
      ]),
    );
  }

  String normalizeTurkish(String text) {
    return text
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .trim();
  }

  Widget _buildBody(BuildContext context, String driverName, String firma, bool canEditCustomer) {
    // Listen to producers + pending teklifler + assignments simultaneously
    final ureticilerStream = _db
        .collection('ureticiler')
        .where('firmalar', arrayContains: firma)
        .snapshots();
    final tekliflerStream = _db
        .collection('toplayici_teklifleri')
        .where('toplayici', isEqualTo: driverName)
        .where('firma', isEqualTo: firma)
        .where('durum', isEqualTo: 'beklemede')
        .snapshots();
    final atamalarStream = _db
        .collection('toplayici_atamalari')
        .where('toplayici', isEqualTo: driverName)
        .where('firma', isEqualTo: firma)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: atamalarStream,
      builder: (context, atamalarSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: ureticilerStream,
          builder: (context, ureticiSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: tekliflerStream,
              builder: (context, teklifSnap) {
                if (ureticiSnap.connectionState == ConnectionState.waiting ||
                    atamalarSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = ureticiSnap.data?.docs ?? [];
                final teklifDocs = teklifSnap.data?.docs ?? [];
                final atamalarDocs = atamalarSnap.data?.docs ?? [];

                // Parse assignments
                final List<String> assignedProducers = [];
                final List<String> assignedGroups = [];
                final List<String> assignedBirlikler = [];

                for (var doc in atamalarDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hTip = data['hedefTip'];
                  final hAd = (data['hedefAd'] as String? ?? '').trim();
                  if (hAd.isEmpty) continue;
                  if (hTip == 'uretici') {
                    assignedProducers.add(hAd);
                  } else if (hTip == 'grup') {
                    assignedGroups.add(hAd);
                  } else if (hTip == 'birlik' || hTip == 'bolge') {
                    assignedBirlikler.add(hAd);
                  }
                }

                final assignedProducersNorm = assignedProducers.map((s) => normalizeTurkish(s)).toSet();
                final assignedGroupsNorm = assignedGroups.map((s) => normalizeTurkish(s)).toSet();
                final assignedBirliklerNorm = assignedBirlikler.map((s) => normalizeTurkish(s)).toSet();

                // Build pending map: ureticiId → teklif data
                final pendingMap = <String, Map<String, dynamic>>{};
                // Also track 'ekle' pending
                final pendingEkleDocs = <Map<String, dynamic>>[];

                for (var d in teklifDocs) {
                  final data = d.data() as Map<String, dynamic>;
                  final tip = data['tip'] as String?;
                  final uId = data['ureticiId'] as String?;
                  if (tip == 'ekle') {
                    pendingEkleDocs.add({...data, '_docId': d.id});
                  } else if (uId != null) {
                    pendingMap[uId] = {...data, '_docId': d.id};
                  }
                }

                // Filter
                final filtered = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = normalizeTurkish(data['name'] ?? '');
                  final group = normalizeTurkish(data['group'] ?? '');
                  final bolge = normalizeTurkish(data['bolge'] ?? '');
                  final birlik = normalizeTurkish(data['birlik'] ?? 'Yok');

                  final isAssigned = assignedProducersNorm.contains(name) ||
                      (assignedGroupsNorm.isNotEmpty && group.isNotEmpty && assignedGroupsNorm.contains(group)) ||
                      (assignedBirliklerNorm.isNotEmpty && bolge.isNotEmpty && assignedBirliklerNorm.contains(bolge)) ||
                      (assignedBirliklerNorm.isNotEmpty && birlik.isNotEmpty && birlik != 'yok' && assignedBirliklerNorm.contains(birlik));

                  if (!isAssigned) return false;

                  final nameLower = (data['name'] as String? ?? '').toLowerCase();
                  return _search.isEmpty || nameLower.contains(_search);
                }).toList();

            filtered.sort((a, b) {
              final an = (a.data() as Map)['name'] as String? ?? '';
              final bn = (b.data() as Map)['name'] as String? ?? '';
              return an.compareTo(bn);
            });

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Pending 'ekle' requests at the top
                ...pendingEkleDocs.map((t) => _buildPendingEkleCard(t)),
                if (pendingEkleDocs.isNotEmpty) const SizedBox(height: 8),

                if (filtered.isEmpty && pendingEkleDocs.isEmpty)
                  _buildEmpty()
                else
                  ...filtered.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final pending = pendingMap[doc.id];
                    return _buildUreticiCard(
                      context, driverName, firma,
                      docId: doc.id, data: data, pendingTeklif: pending,
                      canEditCustomer: canEditCustomer,
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  },
);
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const Icon(Icons.people_outline_rounded, size: 52, color: AppColors.gray300),
          const SizedBox(height: 12),
          Text('Firmanıza kayıtlı üretici bulunamadı.',
              style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildPendingEkleCard(Map<String, dynamic> teklif) {
    final data = teklif['yeniData'] as Map<String, dynamic>? ?? {};
    final name = data['name'] ?? '—';
    final phone = data['phone'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
          Text(phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
          child: Text('Onay Bekliyor', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
        ),
      ]),
    );
  }

  Widget _buildUreticiCard(
    BuildContext context,
    String driverName,
    String firma, {
    required String docId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? pendingTeklif,
    required bool canEditCustomer,
  }) {
    final name = data['name'] as String? ?? '—';
    final phone = data['phone'] as String? ?? '';
    final bolge = data['bolge'] as String? ?? '';
    final group = data['group'] as String? ?? '';
    final customerType = data['customerType'] as String? ?? 'sut';
    final hasPending = pendingTeklif != null;
    final pendingTip = pendingTeklif?['tip'] as String?;
    final hasLocation = data['latitude'] != null && data['longitude'] != null ||
        (data['mapsLink'] as String? ?? '').trim().isNotEmpty;

    Color cardBorderColor = hasPending ? const Color(0xFFFBBF24) : AppColors.gray200;
    Color cardBg = hasPending ? const Color(0xFFFFFBEB) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor, width: hasPending ? 1.5 : 1),
        boxShadow: AppShadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: customerType == 'yem' ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                customerType == 'yem' ? Icons.grass_rounded : Icons.water_drop_rounded,
                color: customerType == 'yem' ? const Color(0xFF16A34A) : AppColors.primary600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray900),
                      overflow: TextOverflow.ellipsis),
                ),
                if (hasPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      pendingTip == 'duzenle' ? '⏳ Düzenleme' : '⏳ Silme',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                    ),
                  ),
              ]),
              if (phone.isNotEmpty)
                Text(phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
            ])),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 12, color: AppColors.gray400),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                bolge.isNotEmpty || group.isNotEmpty
                    ? '$bolge${group.isNotEmpty ? " / $group" : ""}'
                    : (hasLocation ? 'Konum Kayıtlı' : 'Konum Girilmemiş'),
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            MapLinkIcon(
              latitude: (data['latitude'] as num?)?.toDouble(),
              longitude: (data['longitude'] as num?)?.toDouble(),
              mapsLink: data['mapsLink'] as String?,
              fallbackAddress: (bolge.isNotEmpty || group.isNotEmpty) ? '$bolge $group' : name,
            ),
          ]),
          if (!hasPending) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (canEditCustomer) ...[
                OutlinedButton.icon(
                  onPressed: () => _showEditDialog(context, driverName, firma, docId, data),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: Text('Düzenle', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary300),
                    foregroundColor: AppColors.primary600,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => _showDeleteConfirm(context, driverName, firma, docId, data),
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: Text('Sil', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Bu üretici için bekleyen bir ${pendingTip == "sil" ? "silme" : "düzenleme"} talebi mevcut.',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD97706)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Milk type selector widget (reuse) ────────────────────────────────────────

class _MilkTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const _MilkTypeSelector({
    required this.selectedType,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const types = ['Soğuk Süt', 'Sıcak Süt', 'C kalite', 'D kalite'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Süt Türü', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray600)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: types.map((t) {
          final selected = selectedType == t && enabled;
          return ChoiceChip(
            label: Text(t, style: GoogleFonts.inter(fontSize: 11, color: selected ? Colors.white : AppColors.gray700)),
            selected: selected,
            onSelected: enabled ? (_) => onChanged(t) : null,
            selectedColor: AppColors.primary600,
            backgroundColor: AppColors.gray100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: selected ? AppColors.primary600 : AppColors.gray300),
          );
        }).toList(),
      ),
    ]);
  }
}

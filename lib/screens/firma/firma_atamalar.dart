import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaAtamalarScreen extends StatefulWidget {
  const FirmaAtamalarScreen({super.key});

  @override
  State<FirmaAtamalarScreen> createState() => _FirmaAtamalarScreenState();
}

class _FirmaAtamalarScreenState extends State<FirmaAtamalarScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<DocumentSnapshot> _currentDocs = [];

  List<String> _getExistingTargets(String driver, String targetType) {
    final typeVal = targetType == 'Üretici' ? 'uretici' : (targetType == 'Grup' ? 'grup' : 'birlik');
    return _currentDocs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['toplayici'] == driver && data['hedefTip'] == typeVal;
        })
        .map((doc) => (doc.data() as Map<String, dynamic>)['hedefAd'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  void _showAddAssignmentDialog({
    String? initialDriver,
    String? initialTargetType,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch lists
    final driversQuery = await _db.collection('suruculer').where('firma', isEqualTo: currentFirmaName).get();
    final drivers = driversQuery.docs.map((d) {
      final data = d.data();
      return '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim();
    }).where((d) => d.isNotEmpty).toList();

    final vehiclesQuery = await _db.collection('araclar').where('firma', isEqualTo: currentFirmaName).get();
    final Map<String, String> driverPlates = {};
    for (var doc in vehiclesQuery.docs) {
      final data = doc.data();
      final plate = data['plaka'] as String? ?? '';
      final List<String> suruculer = List<String>.from(data['suruculer'] ?? []);
      for (var driver in suruculer) {
        driverPlates[driver.trim().toLowerCase()] = plate;
      }
    }

    final producersQuery = await _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).get();
    final producers = producersQuery.docs.map((p) => p.data()['name'] as String? ?? '').where((p) => p.isNotEmpty).toList();

    final Map<String, String> producerGroupMap = {};
    final Map<String, String> producerBirlikMap = {};
    for (var doc in producersQuery.docs) {
      final data = doc.data();
      final name = data['name'] as String? ?? '';
      if (name.isNotEmpty) {
        producerGroupMap[name] = data['group'] as String? ?? 'Yok';
        producerBirlikMap[name] = data['birlik'] as String? ?? 'Yok';
      }
    }

    final groupsQuery = await _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).get();
    final groups = groupsQuery.docs.map((g) => g.data()['ad'] as String? ?? '').where((g) => g.isNotEmpty).toList();

    final birliklerQuery = await _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).get();
    final birlikler = birliklerQuery.docs.map((b) => b.data()['ad'] as String? ?? '').where((b) => b.isNotEmpty).toList();

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atama yapmak için önce en az bir Toplayıcı/Sürücü eklemelisiniz!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedDriver = (initialDriver != null && drivers.contains(initialDriver))
            ? initialDriver
            : (drivers.isNotEmpty ? drivers.first : null);
        String selectedTargetType = initialTargetType ?? 'Üretici'; // Üretici, Grup, Birlik
        List<String> selectedTargets = selectedDriver != null ? _getExistingTargets(selectedDriver!, selectedTargetType) : [];
        String filterGroup = 'Tümü';
        String filterBirlik = 'Tümü';
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final Map<String, String> pToDriver = {};
            final Map<String, String> gToDriver = {};
            final Map<String, String> bToDriver = {};
            for (var doc in _currentDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final toplayici = data['toplayici'] as String? ?? '';
              final hedefTip = data['hedefTip'] as String? ?? '';
              final hedefAd = data['hedefAd'] as String? ?? '';
              if (toplayici.isNotEmpty && hedefAd.isNotEmpty) {
                if (hedefTip == 'uretici') pToDriver[hedefAd] = toplayici;
                if (hedefTip == 'grup') gToDriver[hedefAd] = toplayici;
                if (hedefTip == 'birlik') bToDriver[hedefAd] = toplayici;
              }
            }

            String? getDriver(String pName) {
              if (pToDriver.containsKey(pName)) return pToDriver[pName];
              final pg = producerGroupMap[pName];
              if (pg != null && gToDriver.containsKey(pg)) return gToDriver[pg];
              final pb = producerBirlikMap[pName];
              if (pb != null && pb != 'Yok' && bToDriver.containsKey(pb)) return bToDriver[pb];
              return null;
            }

            // Sort producers: unassigned (Boşta) first, then alphabetical
            final List<String> sortedProducers = List.from(producers);
            sortedProducers.sort((a, b) {
              final driverA = getDriver(a);
              final driverB = getDriver(b);
              final isBostaA = driverA == null;
              final isBostaB = driverB == null;
              if (isBostaA && !isBostaB) return -1;
              if (!isBostaA && isBostaB) return 1;
              return a.compareTo(b);
            });

            // Filter producers list based on selected Group and Birlik filters
            final List<String> filteredProducersList = sortedProducers.where((pName) {
              final pGroup = producerGroupMap[pName] ?? 'Yok';
              final pBirlik = producerBirlikMap[pName] ?? 'Yok';
              final matchesGroup = filterGroup == 'Tümü' || pGroup == filterGroup;
              final matchesBirlik = filterBirlik == 'Tümü' || pBirlik == filterBirlik;
              return matchesGroup && matchesBirlik;
            }).toList();

            final targetItems = selectedTargetType == 'Üretici'
                ? filteredProducersList
                : (selectedTargetType == 'Grup' ? groups : birlikler);

            return AlertDialog(
              title: Text(initialDriver != null ? 'Atama Düzenle' : 'Yeni Atama Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Toplayıcı / Sürücü', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDriver,
                      items: drivers.map((d) {
                        final dLower = d.trim().toLowerCase();
                        final p = driverPlates[dLower];
                        final displayLabel = p != null ? '$d ($p)' : d;
                        return DropdownMenuItem(value: d, child: Text(displayLabel));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedDriver = val;
                          if (selectedDriver != null) {
                            selectedTargets = _getExistingTargets(selectedDriver!, selectedTargetType);
                          } else {
                            selectedTargets.clear();
                          }
                        });
                      },
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    Text('Atama Türü', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedTargetType,
                      items: const [
                        DropdownMenuItem(value: 'Üretici', child: Text('Üretici')),
                        DropdownMenuItem(value: 'Grup', child: Text('Grup / Köy')),
                        DropdownMenuItem(value: 'Birlik', child: Text('Birlik')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedTargetType = val;
                            if (selectedDriver != null) {
                              selectedTargets = _getExistingTargets(selectedDriver!, selectedTargetType);
                            } else {
                              selectedTargets.clear();
                            }
                          });
                        }
                      },
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    if (selectedTargetType == 'Üretici') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Grup Filtresi', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: filterGroup,
                                  items: ['Tümü', 'Yok', ...groups].map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        filterGroup = val;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Birlik Filtresi', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: filterBirlik,
                                  items: ['Tümü', 'Yok', ...birlikler].map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        filterBirlik = val;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      selectedTargetType == 'Üretici'
                          ? 'Üreticileri Seçin'
                          : (selectedTargetType == 'Grup' ? 'Grup/Köy Seçin' : 'Birlikleri Seçin'),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500),
                    ),
                    const SizedBox(height: 6),
                    if (targetItems.isEmpty)
                      Text(
                        selectedTargetType == 'Üretici'
                            ? 'Filtreye uygun üretici bulunamadı.'
                            : (selectedTargetType == 'Grup' ? 'Kayıtlı grup bulunamadı.' : 'Kayıtlı birlik bulunamadı.'),
                        style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12),
                      )
                    else ...[
                      CheckboxListTile(
                        title: Text('Tümünü Seç', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                        value: targetItems.isNotEmpty && targetItems.every((item) => selectedTargets.contains(item)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              for (var item in targetItems) {
                                if (!selectedTargets.contains(item)) {
                                  selectedTargets.add(item);
                                }
                              }
                            } else {
                              for (var item in targetItems) {
                                selectedTargets.remove(item);
                              }
                            }
                          });
                        },
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.3,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: targetItems.length,
                            itemBuilder: (ctx, idx) {
                              final item = targetItems[idx];
                              final isSelected = selectedTargets.contains(item);
                              String statusText = '';
                              if (selectedTargetType == 'Üretici') {
                                final driver = getDriver(item);
                                statusText = driver != null ? 'Mevcut: $driver' : 'Boşta';
                              } else if (selectedTargetType == 'Grup') {
                                final driver = gToDriver[item];
                                statusText = driver != null ? 'Mevcut: $driver' : 'Boşta';
                              } else if (selectedTargetType == 'Birlik') {
                                final driver = bToDriver[item];
                                statusText = driver != null ? 'Mevcut: $driver' : 'Boşta';
                              }

                              final isBosta = statusText == 'Boşta';

                              return CheckboxListTile(
                                title: Text(item, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                  statusText,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isBosta ? AppColors.success : AppColors.gray500,
                                    fontWeight: isBosta ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                value: isSelected,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedTargets.add(item);
                                    } else {
                                      selectedTargets.remove(item);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: selectedTargets.isEmpty
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            final batch = _db.batch();
                            
                            final typeVal = selectedTargetType == 'Üretici' ? 'uretici' : (selectedTargetType == 'Grup' ? 'grup' : 'birlik');
                            final docsToDelete = _currentDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['toplayici'] == selectedDriver && data['hedefTip'] == typeVal;
                            });

                            for (final doc in docsToDelete) {
                              batch.delete(doc.reference);
                            }

                            for (final target in selectedTargets) {
                              final docRef = _db.collection('toplayici_atamalari').doc();
                              batch.set(docRef, {
                                'toplayici': selectedDriver,
                                'hedefTip': typeVal,
                                'hedefAd': target,
                                'firma': currentFirmaName,
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                            }
                            await batch.commit();

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Atama işlemleri başarıyla tamamlandı!'), backgroundColor: AppColors.success),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ata'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteAssignment(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Atamayı Kaldır', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu atama işlemini iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Atama kaldırıldı!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('araclar')
          .where('firma', isEqualTo: currentFirmaName)
          .snapshots(),
      builder: (context, araclarSnapshot) {
        final vehicleDocs = araclarSnapshot.data?.docs ?? [];
        final Map<String, String> driverPlates = {};
        for (var doc in vehicleDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final plate = data['plaka'] as String? ?? '';
          final List<String> suruculer = List<String>.from(data['suruculer'] ?? []);
          for (var driver in suruculer) {
            driverPlates[driver.trim().toLowerCase()] = plate;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('toplayici_atamalari')
              .where('firma', isEqualTo: currentFirmaName)
              .snapshots(),
          builder: (context, snapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('suruculer')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, suruculerSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('ureticiler')
                      .where('firmalar', arrayContains: currentFirmaName)
                      .snapshots(),
                  builder: (context, ureticilerSnapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        araclarSnapshot.connectionState == ConnectionState.waiting ||
                        suruculerSnapshot.connectionState == ConnectionState.waiting ||
                        ureticilerSnapshot.connectionState == ConnectionState.waiting) {
                      return Scaffold(
                        appBar: AppBar(
                          title: Text(
                            'Atama İşlemleri',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => context.go('/firma/ureticiler'),
                          ),
                        ),
                        backgroundColor: AppColors.gray50,
                        body: const Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    _currentDocs = docs;

                    final suruculerDocs = suruculerSnapshot.data?.docs ?? [];
                    final totalDrivers = suruculerDocs.length;

                    final ureticilerDocs = ureticilerSnapshot.data?.docs ?? [];

                    // Compute mappings
                    final Map<String, String> producerToDriver = {};
                    final Map<String, String> groupToDriver = {};
                    final Map<String, String> birlikToDriver = {};

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final toplayici = data['toplayici'] as String? ?? '';
                      final hedefTip = data['hedefTip'] as String? ?? '';
                      final hedefAd = data['hedefAd'] as String? ?? '';
                      if (toplayici.isNotEmpty && hedefAd.isNotEmpty) {
                        if (hedefTip == 'uretici') {
                          producerToDriver[hedefAd] = toplayici;
                        } else if (hedefTip == 'grup') {
                          groupToDriver[hedefAd] = toplayici;
                        } else if (hedefTip == 'birlik') {
                          birlikToDriver[hedefAd] = toplayici;
                        }
                      }
                    }

                    int assignedProducersCount = 0;
                    int unassignedProducersCount = 0;

                    for (var doc in ureticilerDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? '';
                      final group = data['group'] ?? '';
                      final birlik = data['birlik'] ?? 'Yok';

                      String? assignedDriver;
                      if (producerToDriver.containsKey(name)) {
                        assignedDriver = producerToDriver[name];
                      } else if (group.isNotEmpty && groupToDriver.containsKey(group)) {
                        assignedDriver = groupToDriver[group];
                      } else if (birlik.isNotEmpty && birlik != 'Yok' && birlikToDriver.containsKey(birlik)) {
                        assignedDriver = birlikToDriver[birlik];
                      }

                      if (assignedDriver != null) {
                        assignedProducersCount++;
                      } else {
                        unassignedProducersCount++;
                      }
                    }

                    // Group assignments by driver name
                    final Map<String, List<DocumentSnapshot>> grouped = {};
                    for (final doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final toplayici = data['toplayici'] as String? ?? 'Belirsiz';
                      grouped.putIfAbsent(toplayici, () => []).add(doc);
                    }

                    final driversList = grouped.keys.toList()..sort();

                    return Scaffold(
                      appBar: AppBar(
                        title: Text(
                          'Atama İşlemleri',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => context.go('/firma/ureticiler'),
                        ),
                      ),
                      backgroundColor: AppColors.gray50,
                      floatingActionButton: AppFab(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Yeni Atama',
                        onTap: () => _showAddAssignmentDialog(),
                      ),
                      body: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          StatsGrid(
                            crossAxisCount: 3,
                            spacing: 8,
                            children: [
                              StatCard(
                                icon: Icons.people_alt_rounded,
                                value: '$totalDrivers',
                                label: 'Personel',
                                color: AppColors.primary600,
                              ),
                              StatCard(
                                icon: Icons.person_pin_circle_rounded,
                                value: '$assignedProducersCount',
                                label: 'Atanmış',
                                color: AppColors.success,
                              ),
                              StatCard(
                                icon: Icons.person_outline_rounded,
                                value: '$unassignedProducersCount',
                                label: 'Boşta',
                                color: AppColors.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const SectionTitle(title: 'Atama Listesi'),
                          if (docs.isEmpty)
                            Container(
                              height: 200,
                              alignment: Alignment.center,
                              child: Text(
                                'Sistemde tanımlı atama bulunmuyor.',
                                style: GoogleFonts.inter(color: AppColors.gray500),
                              ),
                            )
                          else
                            ...List.generate(driversList.length, (index) {
                              final driverName = driversList[index];
                              final driverDocs = grouped[driverName]!;
                              final ureticiDocs = driverDocs.where((d) => d['hedefTip'] == 'uretici').toList();
                              final grupDocs = driverDocs.where((d) => d['hedefTip'] == 'grup').toList();
                              final birlikDocs = driverDocs.where((d) => d['hedefTip'] == 'birlik').toList();

                              final driverNameLower = driverName.trim().toLowerCase();
                              final plate = driverPlates[driverNameLower];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: AppShadows.sm,
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    shape: const Border(),
                                    collapsedShape: const Border(),
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.local_shipping_rounded, color: AppColors.primary600, size: 20),
                                      ),
                                    ),
                                    title: Text(
                                      "Toplayıcı: $driverName${plate != null ? ' ($plate)' : ''}",
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gray800),
                                    ),
                                    subtitle: Text(
                                      "${ureticiDocs.length} Üretici, ${grupDocs.length} Grup, ${birlikDocs.length} Birlik",
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                                    ),
                                    children: [
                                      const Divider(height: 1, color: AppColors.gray200),
                                      const SizedBox(height: 8),
                                      ...driverDocs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final hedefTip = data['hedefTip'] == 'uretici'
                                            ? 'Üretici'
                                            : (data['hedefTip'] == 'grup' ? 'Grup' : 'Birlik');
                                        final hedefAd = data['hedefAd'] ?? '';

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.gray50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.gray100),
                                          ),
                                          child: Row(
                                            children: [
                                              StatusBadge.info(hedefTip),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  hedefAd,
                                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                                onPressed: () => _deleteAssignment(doc),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                splashRadius: 20,
                                                tooltip: 'Atamayı Kaldır',
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                      const Divider(height: 1, color: AppColors.gray200),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _showAddAssignmentDialog(
                                              initialDriver: driverName,
                                              initialTargetType: 'Üretici',
                                            ),
                                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                            label: const Text('Üretici Ekle/Çıkar'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              side: const BorderSide(color: AppColors.primary300),
                                              foregroundColor: AppColors.primary700,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () => _showAddAssignmentDialog(
                                              initialDriver: driverName,
                                              initialTargetType: 'Grup',
                                            ),
                                            icon: const Icon(Icons.group_add_rounded, size: 16),
                                            label: const Text('Grup Ekle/Çıkar'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              side: const BorderSide(color: AppColors.primary300),
                                              foregroundColor: AppColors.primary700,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () => _showAddAssignmentDialog(
                                              initialDriver: driverName,
                                              initialTargetType: 'Birlik',
                                            ),
                                            icon: const Icon(Icons.account_balance_rounded, size: 16),
                                            label: const Text('Birlik Ekle/Çıkar'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              side: const BorderSide(color: AppColors.primary300),
                                              foregroundColor: AppColors.primary700,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  }
                );
              }
            );
          },
        );
      },
    );
  }
}

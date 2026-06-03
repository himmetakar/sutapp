import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import '../config/theme.dart';

/// Reusable location picker widget for producer add/edit forms.
/// Shows a single address field, a small "Mevcut Konumu Al" button above it,
/// and a map icon button that opens the coordinates or text address in Google Maps.
class LocationPickerField extends StatefulWidget {
  final TextEditingController latController;
  final TextEditingController lngController;
  final void Function(VoidCallback fn) setDialogState;

  const LocationPickerField({
    super.key,
    required this.latController,
    required this.lngController,
    required this.setDialogState,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  late TextEditingController _addressController;
  bool _isAutoSetting = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.latController.text.trim();
    final lng = widget.lngController.text.trim();
    if (lat.isNotEmpty && lng.isNotEmpty) {
      _addressController = TextEditingController(text: '$lat, $lng');
    } else {
      _addressController = TextEditingController(text: lat);
    }

    _addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    if (_isAutoSetting) return;

    final text = _addressController.text.trim();
    if (text.isEmpty) {
      widget.latController.text = '';
      widget.lngController.text = '';
      return;
    }

    // Check if the text matches a coordinate pattern (e.g. "38.7312, 35.4826")
    final parts = text.split(',');
    if (parts.length == 2) {
      final latVal = double.tryParse(parts[0].trim());
      final lngVal = double.tryParse(parts[1].trim());
      if (latVal != null && lngVal != null) {
        widget.latController.text = parts[0].trim();
        widget.lngController.text = parts[1].trim();
        return;
      }
    }

    // Otherwise, treat as manual address (store address in latController, and clear lngController)
    widget.latController.text = text;
    widget.lngController.text = '';
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final latStr = position.latitude.toStringAsFixed(6);
      final lngStr = position.longitude.toStringAsFixed(6);

      String addressText = '$latStr, $lngStr';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final street = place.street ?? '';
          final subLoc = place.subLocality ?? '';
          final subAdmin = place.subAdministrativeArea ?? '';
          final admin = place.administrativeArea ?? '';
          
          List<String> parts = [];
          if (street.isNotEmpty) parts.add(street);
          if (subLoc.isNotEmpty && subLoc != street) parts.add(subLoc);
          if (subAdmin.isNotEmpty) parts.add(subAdmin);
          if (admin.isNotEmpty) parts.add(admin);

          if (parts.isNotEmpty) {
            addressText = parts.join(', ');
          }
        }
      } catch (geocodingError) {
        debugPrint('Adres çözümleme hatası: $geocodingError');
      }

      widget.setDialogState(() {
        _isAutoSetting = true;
        _addressController.text = addressText;
        widget.latController.text = latStr;
        widget.lngController.text = lngStr;
        _isAutoSetting = false;
      });
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
    }
  }

  void _openInMaps() {
    final text = _addressController.text.trim();
    if (text.isEmpty) return;

    final parts = text.split(',');
    Uri url;
    if (parts.length == 2) {
      final latVal = double.tryParse(parts[0].trim());
      final lngVal = double.tryParse(parts[1].trim());
      if (latVal != null && lngVal != null) {
        url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latVal,$lngVal');
      } else {
        url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(text)}');
      }
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(text)}');
    }

    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: AppColors.gray500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Adres / Harita Konumu',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _getCurrentLocation,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location_rounded, size: 12, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 4),
                    Text(
                      'Mevcut Konumu Al',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Lütfen "Mevcut Konumu Al" butonunu kullanın...',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.gray100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.gray200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.gray200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.gray200),
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _openInMaps,
              tooltip: 'Haritada Aç',
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.map_rounded, size: 20, color: Color(0xFF3B82F6)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small icon button to open a saved location or text address in Google Maps.
/// Use this in list cards for producers that have a stored location/address.
class MapLinkIcon extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? mapsLink;
  final String? fallbackAddress;

  const MapLinkIcon({
    super.key,
    this.latitude,
    this.longitude,
    this.mapsLink,
    this.fallbackAddress,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoords = latitude != null && longitude != null;
    final hasLink = mapsLink != null && mapsLink!.trim().isNotEmpty;
    final hasFallback = fallbackAddress != null && fallbackAddress!.trim().isNotEmpty;

    if (!hasCoords && !hasLink && !hasFallback) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        Uri url;
        if (hasCoords) {
          url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
        } else if (hasLink) {
          final link = mapsLink!.trim();
          if (link.startsWith('http://') || link.startsWith('https://')) {
            url = Uri.parse(link);
          } else {
            url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(link)}');
          }
        } else {
          url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fallbackAddress!.trim())}');
        }
        launchUrl(url, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.map_rounded, size: 14, color: Color(0xFF3B82F6)),
      ),
    );
  }
}

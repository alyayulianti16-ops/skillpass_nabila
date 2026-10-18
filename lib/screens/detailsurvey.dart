import 'dart:convert';
import 'dart:typed_data';
import 'package:field_survey/screens/auth/login.dart';
import 'package:field_survey/screens/surveyformpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SurveyDetailPage extends StatefulWidget {
  final int surveyId;

  const SurveyDetailPage({super.key, required this.surveyId});

  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  Map<String, dynamic>? survey;
  bool isLoading = true;
  String? errorMessage;
  Uint8List? imageBytes;
  bool isLoadingImage = false;
  static const Color primaryColor = Color(0xFF1E40AF);

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      imageBytes = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      final url = Uri.parse(
        'https://sijala.biz.id/api/v1/surveys/${widget.surveyId}',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );

        return;
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == true && result['data'] != null) {
          final data = Map<String, dynamic>.from(result['data']);

          setState(() {
            survey = data;
            isLoading = false;
          });

          final photoName = data['photo']?.toString();

          if (photoName != null &&
              photoName.isNotEmpty &&
              photoName != 'placeholder.jpg') {
            fetchImage(photoName, token);
          }

          return;
        }
      }

      throw Exception('Survey tidak ditemukan (Kode: ${response.statusCode})');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Gagal memuat detail survey. Periksa koneksi Anda.';
      });
    }
  }

  Future<void> fetchImage(String photoName, String token) async {
    setState(() {
      isLoadingImage = true;
    });

    try {
      final fileName = photoName.contains('/')
          ? photoName.split('/').last
          : photoName;

      final url = Uri.parse('https://sijala.biz.id/api/image/$fileName');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          imageBytes = response.bodyBytes;
          isLoadingImage = false;
        });

        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        isLoadingImage = false;
      });
    }
  }

  Future<void> deleteSurvey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus survey'),
        content: const Text('Apakah anda yakin ingin menghapus survey ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse(
          'https://sijala.biz.id/api/v1/surveys/${widget.surveyId}/delete',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Survey berhasil dihapus!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menghapus survey (Kode: ${response.statusCode})',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat menghapus survey.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> editSurvey() async {
    if (survey == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SurveyFormPage(survey: survey)),
    );

    if (result == true && mounted) {
      fetchDetail();
    }
  }

  Future<void> openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
      );
    }
  }

  void copyCoordinates(double lat, double lng) {
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Koordinat berhasil disalin!')),
    );
  }

  void showFullImageDialog(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 253),
      appBar: AppBar(
        title: const Text(
          'Detail Survey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[100],
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,

        actions: [
          if (survey != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Survey',
              onPressed: editSurvey,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Hapus Survey',
              onPressed: deleteSurvey,
            ),
          ],
        ],
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text(
              'Memuat detail survey...',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null || survey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage ?? 'Survey tidak ditemukan',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: fetchDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final title = survey!['title']?.toString() ?? '-';
    final description = survey!['description']?.toString() ?? '-';
    final category =
        survey!['category']?.toString() ??
        survey!['category']?['name']?.toString() ??
        'Tanpa Kategori';
    final date = survey!['created_at']?.toString() ?? '-';
    final lat = double.tryParse(survey!['latitude']?.toString() ?? '');
    final lng = double.tryParse(survey!['longitude']?.toString() ?? '');
    final hasValidCoords = lat != null && lng != null;

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: fetchDetail,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Waktu: $date',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'Foto Survey',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (isLoadingImage)
                  const SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                else if (imageBytes != null)
                  GestureDetector(
                    onTap: () => showFullImageDialog(imageBytes!),
                    child: Image.memory(
                      imageBytes!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: Text(
                        'Tidak ada foto survey',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokasi Survey',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasValidCoords
                            ? 'Koordinat: $lat, $lng'
                            : 'Koordinat tidak tersedia',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasValidCoords) ...[
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.field_survey',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: primaryColor,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => copyCoordinates(lat, lng),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Salin Koordinat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: const BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => openGoogleMaps(lat, lng),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Buka Maps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Container(
                    height: 100,
                    width: double.infinity,
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: Text(
                        'Peta tidak tersedia (koordinat kosong)',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

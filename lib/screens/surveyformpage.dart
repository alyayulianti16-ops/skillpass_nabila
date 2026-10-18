import 'dart:convert';
import 'dart:typed_data';

import 'package:field_survey/screens/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurveyFormPage extends StatefulWidget {
  final Map<String, dynamic>? survey;

  const SurveyFormPage({
    super.key,
    this.survey,
  });

  @override
  State<SurveyFormPage> createState() => _SurveyFormPageState();
}

class _SurveyFormPageState extends State<SurveyFormPage> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  int? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isLoadingCategories = true;

  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  Uint8List? existingImageBytes;

  bool isSubmitting = false;

  bool get isEdit => widget.survey != null;

  static const Color primaryColor = Color(0xFF1E40AF);

  // Controller dan posisi untuk Peta
  LatLng selectedPosition = const LatLng(-6.98326, 108.90287);
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    checkAuthentication();

    if (isEdit) {
      final s = widget.survey!;

      titleController.text = s['title']?.toString() ?? '';

      descriptionController.text = s['description']?.toString() == '-'
          ? ''
          : s['description']?.toString() ?? '';

      latitudeController.text = s['latitude']?.toString() ?? '';
      longitudeController.text = s['longitude']?.toString() ?? '';

      // Set posisi peta jika data koordinat tersedia di survey
      final double? lat = double.tryParse(s['latitude']?.toString() ?? '');
      final double? lng = double.tryParse(s['longitude']?.toString() ?? '');
      if (lat != null && lng != null) {
        selectedPosition = LatLng(lat, lng);
      }

      selectedCategoryId = int.tryParse(
        s['category_id']?.toString() ?? '',
      );

      final photoName = s['photo']?.toString();

      if (photoName != null &&
          photoName.isNotEmpty &&
          photoName != 'placeholder.jpg') {
        fetchExistingImage(photoName);
      }
    } else {
      // Default nilai awal untuk input latitude & longitude jika tambah baru
      latitudeController.text = selectedPosition.latitude.toString();
      longitudeController.text = selectedPosition.longitude.toString();
    }

    fetchCategories();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();

    super.dispose();
  }

  void _updatePositionFromControllers() {
    final double? lat = double.tryParse(latitudeController.text);
    final double? lng = double.tryParse(longitudeController.text);

    if (lat != null && lng != null) {
      setState(() {
        selectedPosition = LatLng(lat, lng);
      });
      mapController.move(selectedPosition, mapController.camera.zoom);
    }
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      selectedPosition = point;
      latitudeController.text = point.latitude.toStringAsFixed(6);
      longitudeController.text = point.longitude.toStringAsFixed(6);
    });
  }

  Future<void> checkAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoadingCategories = false;
        });

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );

        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://sijala.biz.id/api/v1/categories',
        ),
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
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );

        return;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded['data'] is List) {
          final List rawList = decoded['data'];

          if (!mounted) return;

          setState(() {
            categories = rawList
                .whereType<Map>()
                .map(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList();

            isLoadingCategories = false;
          });

          return;
        }
      }
    } catch (e) {
      debugPrint('ERROR CATEGORY: $e');
    }

    if (mounted) {
      setState(() {
        isLoadingCategories = false;
      });
    }
  }

  Future<void> fetchExistingImage(String photoName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final fileName = photoName.contains('/')
          ? photoName.split('/').last
          : photoName;

      final response = await http.get(
        Uri.parse(
          'https://sijala.biz.id/api/image/$fileName',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          existingImageBytes = response.bodyBytes;
        });
      }
    } catch (e) {
      debugPrint('ERROR IMAGE: $e');
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          selectedImage = pickedFile;
          selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      showErrorSnackBar('Gagal memilih foto.');
    }
  }

  void removeSelectedImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
      existingImageBytes = null;
    });
  }

  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: primaryColor,
                  ),
                  title: const Text('Galeri'),
                  onTap: () {
                    Navigator.pop(ctx);
                    pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: primaryColor,
                  ),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> saveSurvey() async {
    if (!formKey.currentState!.validate()) {
      showErrorSnackBar('Lengkapi data yang wajib diisi.');
      return;
    }

    if (selectedCategoryId == null || selectedCategoryId == 0) {
      showErrorSnackBar('Kategori survey wajib dipilih.');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );

        return;
      }

      final uri = Uri.parse(
        'https://sijala.biz.id/api/v1/surveys/save',
      );

      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = titleController.text.trim();
      request.fields['category_id'] = selectedCategoryId.toString();
      request.fields['description'] = descriptionController.text.trim();

      if (latitudeController.text.trim().isNotEmpty) {
        request.fields['latitude'] = latitudeController.text.trim();
      }

      if (longitudeController.text.trim().isNotEmpty) {
        request.fields['longitude'] = longitudeController.text.trim();
      }

      if (isEdit) {
        request.fields['id'] = widget.survey!['id'].toString();
        request.fields['_method'] = 'PUT';
      }

      if (selectedImage != null && selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        showErrorSnackBar('Session telah berakhir. Silakan login kembali.');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );

        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Survey berhasil diperbarui!'
                  : 'Survey berhasil disimpan!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      if (response.statusCode == 422) {
        String message = 'Data yang dikirim tidak valid.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
          if (decoded is Map && decoded['errors'] != null) {
            message = decoded['errors'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }

      if (response.statusCode == 500) {
        String message = 'Terjadi kesalahan pada server.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {
          if (response.body.trim().isNotEmpty) {
            message = response.body;
          }
        }
        throw Exception('Server Error (500): $message');
      }

      throw Exception('Gagal menyimpan (Kode: ${response.statusCode})');
    } catch (e) {
      debugPrint('ERROR SAVE SURVEY: $e');

      if (!mounted) return;

      showErrorSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Survey' : 'Tambah Survey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[100],
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Utama Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Judul Survey *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan judul survey',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.title,
                            color: primaryColor,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Judul wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kategori Survey *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isLoadingCategories)
                        const LinearProgressIndicator(
                          color: primaryColor,
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: selectedCategoryId,
                          decoration: const InputDecoration(
                            hintText: 'Pilih Kategori',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.category,
                              color: primaryColor,
                            ),
                          ),
                          items: categories.map((cat) {
                            final id = int.tryParse(
                                  cat['id']?.toString() ?? '',
                                ) ??
                                0;
                            final name = cat['name']?.toString() ?? '-';

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedCategoryId = val;
                            });
                          },
                          validator: (val) {
                            if (val == null || val == 0) {
                              return 'Kategori wajib dipilih';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Deskripsi Survey',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Keterangan atau catatan survey...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.notes,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokasi Survey (Peta & Koordinat)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: latitudeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => _updatePositionFromControllers(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: longitudeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => _updatePositionFromControllers(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedPosition,
                              initialZoom: 15.0,
                              onTap: (tapPosition, point) => _onMapTapped(point),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.field_survey',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: selectedPosition,
                                    width: 45,
                                    height: 45,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: primaryColor,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card Foto Survey
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedImageBytes != null ||
                          existingImageBytes != null)
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                selectedImageBytes ?? existingImageBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: showImageSourceDialog,
                                    icon: const Icon(
                                      Icons.photo_library,
                                    ),
                                    label: const Text('Ganti Foto'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: removeSelectedImage,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                  ),
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: showImageSourceDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 36,
                                  color: primaryColor,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tambah Foto Survey',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : saveSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'Perbarui Survey' : 'Simpan Survey',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
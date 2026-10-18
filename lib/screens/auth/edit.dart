// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class EditProfilePage extends StatefulWidget {
//   final String nama;
//   final String username;
//   final String email;
//   final String phone;
//   final String gender;
//   final String birthPlace;
//   final String birthDate;
//   final String photo;

//   const EditProfilePage({
//     super.key,
//     this.nama = '',
//     this.username = '',
//     this.email = '',
//     this.phone = '',
//     this.gender = 'Perempuan',
//     this.birthPlace = '',
//     this.birthDate = '',
//     this.photo = '',
//   });

//   @override
//   State<EditProfilePage> createState() => _EditProfilePageState();
// }

// class _EditProfilePageState extends State<EditProfilePage> {
//   late TextEditingController namaController;
//   late TextEditingController usernameController;
//   late TextEditingController emailController;
//   late TextEditingController phoneController;
//   late TextEditingController birthPlaceController;

//   String gender = 'Perempuan';
//   DateTime? selectedDate;

//   Uint8List? selectedImage;
//   final ImagePicker imagePicker = ImagePicker();
//   bool isLoading = false;

//   static const Color primaryBlue = Color(0xFF1E40AF);

//   @override
//   void initState() {
//     super.initState();

//     namaController = TextEditingController(text: widget.nama);
//     usernameController = TextEditingController(text: widget.username);
//     emailController = TextEditingController(text: widget.email);
//     phoneController = TextEditingController(text: widget.phone);
//     birthPlaceController = TextEditingController(text: widget.birthPlace);

//     gender = widget.gender.isEmpty ? 'Perempuan' : widget.gender;

//     if (widget.birthDate.isNotEmpty) {
//       selectedDate = DateTime.tryParse(widget.birthDate);
//     }
//   }

//   @override
//   void dispose() {
//     namaController.dispose();
//     usernameController.dispose();
//     emailController.dispose();
//     phoneController.dispose();
//     birthPlaceController.dispose();
//     super.dispose();
//   }

//   Future<void> pilihFoto() async {
//     final XFile? image = await imagePicker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 80,
//     );

//     if (image != null) {
//       final Uint8List bytes = await image.readAsBytes();
//       setState(() {
//         selectedImage = bytes;
//       });
//     }
//   }

//   Future<void> pilihTanggalLahir() async {
//     final DateTime initialDate = selectedDate ?? DateTime(2005, 1, 1);

//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: initialDate,
//       firstDate: DateTime(1950),
//       lastDate: DateTime.now(),
//       helpText: 'Pilih Tanggal Lahir',
//       cancelText: 'BATAL',
//       confirmText: 'PILIH',
//     );

//     if (picked != null) {
//       setState(() {
//         selectedDate = picked;
//       });
//     }
//   }

//   String formatTanggal(DateTime? date) {
//     if (date == null) return 'Belum tersedia';
//     final String day = date.day.toString().padLeft(2, '0');
//     final String month = date.month.toString().padLeft(2, '0');
//     final String year = date.year.toString();
//     return '$day/$month/$year';
//   }

//   String formatTanggalApi(DateTime? date) {
//     if (date == null) return '';
//     final String month = date.month.toString().padLeft(2, '0');
//     final String day = date.day.toString().padLeft(2, '0');
//     return '${date.year}-$month-$day';
//   }

//   Future<void> simpanProfile() async {
//     if (namaController.text.trim().isEmpty) {
//       tampilkanPesan('Nama tidak boleh kosong');
//       return;
//     }

//     if (phoneController.text.trim().isEmpty) {
//       tampilkanPesan('Nomor telepon tidak boleh kosong');
//       return;
//     }

//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('token');

//       if (token == null || token.isEmpty) {
//         throw Exception('Token tidak ditemukan, silakan login ulang.');
//       }

//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('https://sijala.biz.id/api/v1/update-profile'),
//       );

//       // Method spoofing agar Laravel membaca ini sebagai PUT
//       request.fields['_method'] = 'PUT';

//       request.headers.addAll({
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $token',
//       });

//       request.fields['name'] = namaController.text.trim();
//       request.fields['username'] = usernameController.text.trim();
//       request.fields['email'] = emailController.text.trim();
//       request.fields['phone'] = phoneController.text.trim();
//       request.fields['gender'] = gender;
//       request.fields['birth_place'] = birthPlaceController.text.trim();
//       request.fields['birth_date'] = formatTanggalApi(selectedDate);

//       if (selectedImage != null) {
//         request.files.add(
//           http.MultipartFile.fromBytes(
//             'photo',
//             selectedImage!,
//             filename: 'profile_image.jpg',
//           ),
//         );
//       }

//       var streamedResponse = await request.send();
//       var response = await http.Response.fromStream(streamedResponse);

//       if (response.statusCode == 200) {
//         tampilkanPesan('Profil berhasil diperbarui');

//         if (!mounted) return;
//         Navigator.pop(context, true);
//       } else {
//         final errorData = jsonDecode(response.body);
//         throw Exception(errorData['message'] ?? 'Gagal memperbarui profil');
//       }
//     } catch (e) {
//       tampilkanPesan(e.toString().replaceFirst('Exception: ', ''));
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//     }
//   }

//   void tampilkanPesan(String pesan) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(pesan),
//         behavior: SnackBarBehavior.floating,
//         backgroundColor: primaryBlue,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }

//   Widget inputField({
//     required String label,
//     required IconData icon,
//     required TextEditingController controller,
//     TextInputType keyboardType = TextInputType.text,
//     bool readOnly = false,
//   }) {
//     return TextField(
//       controller: controller,
//       keyboardType: keyboardType,
//       readOnly: readOnly,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon, color: primaryBlue),
//         filled: true,
//         fillColor: Colors.white,
//         contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(15),
//           borderSide: BorderSide.none,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(15),
//           borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(15),
//           borderSide: const BorderSide(color: primaryBlue, width: 2),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         backgroundColor: primaryBlue,
//         elevation: 0,
//         centerTitle: true,
//         foregroundColor: Colors.white,
//         title: const Text(
//           'Edit Profile',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//       ),
//       body: SafeArea(
//         child: isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : SingleChildScrollView(
//                 padding: const EdgeInsets.all(20),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Edit Data Profile',
//                       style: TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                         color: Color(0xFF0F172A),
//                       ),
//                     ),
//                     const SizedBox(height: 5),
//                     const Text(
//                       'Ubah informasi profile kamu di bawah ini',
//                       style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
//                     ),
//                     const SizedBox(height: 25),
//                     Center(
//                       child: Column(
//                         children: [
//                           GestureDetector(
//                             onTap: pilihFoto,
//                             child: Stack(
//                               children: [
//                                 CircleAvatar(
//                                   radius: 55,
//                                   backgroundColor: const Color(0xFFDBEAFE),
//                                   backgroundImage: selectedImage != null
//                                       ? MemoryImage(selectedImage!)
//                                       : null,
//                                   child: selectedImage == null
//                                       ? const Icon(
//                                           Icons.person,
//                                           size: 60,
//                                           color: primaryBlue,
//                                         )
//                                       : null,
//                                 ),
//                                 Positioned(
//                                   bottom: 0,
//                                   right: 0,
//                                   child: Container(
//                                     width: 35,
//                                     height: 35,
//                                     decoration: BoxDecoration(
//                                       color: primaryBlue,
//                                       shape: BoxShape.circle,
//                                       border: Border.all(
//                                         color: Colors.white,
//                                         width: 3,
//                                       ),
//                                     ),
//                                     child: const Icon(
//                                       Icons.camera_alt,
//                                       size: 18,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           const Text(
//                             'Ketuk foto untuk mengganti foto profil',
//                             style: TextStyle(
//                               fontSize: 13,
//                               color: Color(0xFF64748B),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 25),
//                     inputField(
//                       label: 'Nama Lengkap',
//                       icon: Icons.person_outline,
//                       controller: namaController,
//                     ),
//                     const SizedBox(height: 15),
//                     inputField(
//                       label: 'Username',
//                       icon: Icons.account_circle_outlined,
//                       controller: usernameController,
//                     ),
//                     const SizedBox(height: 15),
//                     inputField(
//                       label: 'Email',
//                       icon: Icons.email_outlined,
//                       controller: emailController,
//                       keyboardType: TextInputType.emailAddress,
//                     ),
//                     const SizedBox(height: 15),
//                     inputField(
//                       label: 'Nomor Telepon',
//                       icon: Icons.phone_outlined,
//                       controller: phoneController,
//                       keyboardType: TextInputType.phone,
//                     ),
//                     const SizedBox(height: 30),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 55,
//                       child: ElevatedButton.icon(
//                         onPressed: simpanProfile,
//                         icon: const Icon(
//                           Icons.save_outlined,
//                           color: Colors.white,
//                         ),
//                         label: const Text(
//                           'SIMPAN PERUBAHAN',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: primaryBlue,
//                           elevation: 0,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 15),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 55,
//                       child: OutlinedButton(
//                         onPressed: () {
//                           Navigator.pop(context);
//                         },
//                         style: OutlinedButton.styleFrom(
//                           foregroundColor: primaryBlue,
//                           side: const BorderSide(color: primaryBlue),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                         ),
//                         child: const Text(
//                           'BATAL',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//       ),
//     );
//   }
// }
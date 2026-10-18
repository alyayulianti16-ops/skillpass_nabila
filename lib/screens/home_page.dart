import 'dart:convert';
import 'package:field_survey/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  String userName = '';
  
  int totalSurvey = 0;
  List<dynamic> recentSurveys = [];

  @override
  void initState() {
    super.initState();
    loadUserDataAndDashboard();
  }

  Future<void> loadUserDataAndDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final String storedName = prefs.getString('nama') ?? 'Surveyor';
    
    setState(() {
      userName = storedName;
    });

    await fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        context.go(AppRoutes.login);
        return;
      }

      final response = await http.get(
        Uri.parse('https://sijala.biz.id/api/v1/dashboard'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        setState(() {
          totalSurvey = data['total_surveys'] ?? data['total'] ?? 0;
          
          if (data['recent_surveys'] is List) {
            recentSurveys = data['recent_surveys'];
          } else if (data['surveys'] is List) {
            recentSurveys = data['surveys'];
          }
          
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        await prefs.clear();
        if (!mounted) return;
        context.go(AppRoutes.login);
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[100],
        elevation: 0,
        title: const Text(
          'Field Survey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.push(AppRoutes.profile_page);
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.blue[700],
              ),
            )
          : RefreshIndicator(
              color: Colors.blue[700],
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $userName 👋',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Selamat Datang!',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mulai Survey',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Lakukan survey dengan mudah dan cepat.',
                                ),
                                const SizedBox(height: 15),
                                ElevatedButton(
                                  onPressed: () async {
                                    final result = await context.push(AppRoutes.surveyformpage);
                                    if (result == true) {
                                      fetchDashboardData(); 
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Mulai'),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.assignment_turned_in,
                            size: 75,
                            color: Colors.blue[700],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Statistik & Akun',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // Baris Statistik Total & Profil
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.assignment,
                            title: 'Total Survey',
                            value: totalSurvey.toString(),
                            onTap: () {
                              // Navigasi ke halaman Daftar Survey saat diklik
                              context.push(AppRoutes.survey_page);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            icon: Icons.person,
                            title: 'Profil Saya',
                            value: userName,
                            onTap: () {
                              context.push(AppRoutes.profile_page);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  } ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.blue[700],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
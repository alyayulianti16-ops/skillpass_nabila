import 'package:field_survey/screens/profile_page.dart';
import 'package:field_survey/screens/survey_page.dart';
import 'package:field_survey/screens/surveyformpage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:field_survey/routes/app_routes.dart';
import 'package:field_survey/screens/auth/login.dart';
import 'package:field_survey/screens/auth/register.dart';
import 'package:field_survey/screens/dashboar.dart';
import 'package:field_survey/screens/splash/splash_screen.dart';

class AppPages {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final sudahLogin = token != null && token.isNotEmpty;

      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isLogin = state.matchedLocation == AppRoutes.login;
      final isRegister = state.matchedLocation == AppRoutes.register;
      if (isSplash) {
        return null;
      }
      if (!sudahLogin && !isLogin && !isRegister) {
        return AppRoutes.login;
      }
      if (sudahLogin && (isLogin || isRegister)) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(path: AppRoutes.surveyformpage,
      builder: (context, state) => const SurveyFormPage(),
      ),
      GoRoute(path: AppRoutes.profile_page,
      builder: (context, state) => const ProfilePage(),
      ),
       GoRoute(path: AppRoutes.survey_page,
      builder: (context, state) => const SurveyPage(),
      ),
    ],
  );
}
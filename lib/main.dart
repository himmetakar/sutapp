import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar: white bg, dark icons
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }

  // Initialize Firestore mock data (Only in dev/demo mode)
  if (!AppConstants.isProduction) {
    await FirestoreService().initializeMockDataIfNeeded();
  }

  final authProvider = AuthProvider();
  await authProvider.loadSavedSession();

  initializeDateFormatting('tr_TR', null).then((_) {
    runApp(SutApp(authProvider: authProvider));
  });
}

class SutApp extends StatefulWidget {
  final AuthProvider authProvider;
  const SutApp({super.key, required this.authProvider});

  @override
  State<SutApp> createState() => _SutAppState();
}

class _SutAppState extends State<SutApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: widget.authProvider,
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          _router ??= createRouter(auth);
          return MaterialApp.router(
            title: 'SütApp',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: _router!,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('tr', 'TR'),
              Locale('en', 'US'),
            ],
            locale: const Locale('tr', 'TR'),
          );
        },
      ),
    );
  }
}


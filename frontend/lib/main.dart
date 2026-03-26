import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: AgroStreetMarketApp()));
}

class AgroStreetMarketApp extends ConsumerWidget {
  const AgroStreetMarketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Agro Street Market',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

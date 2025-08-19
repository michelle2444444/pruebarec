//MainDart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zdlefsxbrpmltahhbckx.supabase.co',  
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpkbGVmc3hicnBtbHRhaGhiY2t4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU2MTc3NjEsImV4cCI6MjA3MTE5Mzc2MX0.132yvbzINpyHzH4j4NxOH8rmPH8V-nUi2p1lwOeo7jc',                 
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Supabase Auth Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthPage(),
    );
  }
}
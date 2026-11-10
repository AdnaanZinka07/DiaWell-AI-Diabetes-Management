import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
/*Backend stop
sudo fuser -k 8001/tcp
*/
/* To run backend run this
cd /home/adnaanzinka/development/Diawell/backend
source venv/bin/activate
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8001


For localhost
http://localhost:8001/redoc
 */

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Check if user is already logged in
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiaWell',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,

      //Ensure user stays logged in
      initialRoute: isLoggedIn ? '/home' : '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/feed': (context) => const FeedScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

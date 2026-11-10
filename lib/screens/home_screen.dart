import 'package:flutter/material.dart';
import 'add_sugar_level_screen.dart';
import 'add_medication_screen.dart';
import 'reports_screen.dart';
import 'feed_screen.dart';
import 'profile_screen.dart' as profile;
import 'chatbot_screen.dart'; // Import Chatbot Screen
import 'HomeContent.dart'; //  Import HomeContent file if it's in a separate file

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeContent(), // ✅ Fixed HomeContent
    const ReportsScreen(),
    const FeedScreen(),
    const profile.ProfileScreen(),
    const ChatbotScreen(), // ✅ Added Chatbot as the 5th screen
  ];

  void _onItemTapped(int index) {
    setState(() {
      if (index < _widgetOptions.length) { // ✅ Prevent out-of-range errors
        _selectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          _widgetOptions.elementAt(_selectedIndex),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Medication FAB
                _buildFAB(
                  label: "Medication",
                  icon: Icons.medical_services,
                  backgroundColor: Colors.green,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                // Sugar Level FAB
                _buildFAB(
                  label: "Sugar Level",
                  icon: Icons.add_chart,
                  backgroundColor: Colors.orangeAccent,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddSugarLevelScreen()),
                    );
                  },
                ),
              ],
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            showUnselectedLabels: false,
            elevation: 10,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Reports'),
              BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Updates'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'ChatBot'), // ✅ Chatbot added
            ],
          ),
        ),
      ),
    );
  }

  // Floating Action Button Widget (For Medication & Sugar Level)
  Widget _buildFAB({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      label: Text(label),
      icon: Icon(icon),
      backgroundColor: backgroundColor,
      elevation: 6,
      heroTag: label,
    );
  }
}

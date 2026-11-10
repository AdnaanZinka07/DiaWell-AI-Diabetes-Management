import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedUnit = "mg/dL";
  String selectedLanguage = "English";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Sugar Target Range
              _buildSettingsCard(
                title: "Sugar Target Range",
                subtitle: "Set your ideal blood sugar range",
                icon: Icons.monitor_heart,
                iconColor: Colors.red,
                onTap: () {
                  // Future: Implement range selection
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Feature coming soon!")),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Unit Selection (mg/dL or mmol/L)
              _buildDropDownCard(
                title: "Unit",
                subtitle: selectedUnit,
                icon: Icons.straighten,
                iconColor: Colors.blue,
                dropdownValue: selectedUnit,
                dropdownItems: ["mg/dL", "mmol/L"],
                onChanged: (String? newValue) {
                  setState(() {
                    selectedUnit = newValue!;
                  });
                },
              ),

              const SizedBox(height: 12),

              // Language Options
              _buildDropDownCard(
                title: "Language Options",
                subtitle: selectedLanguage,
                icon: Icons.language,
                iconColor: Colors.purple,
                dropdownValue: selectedLanguage,
                dropdownItems: ["English", "Spanish", "French"],
                onChanged: (String? newValue) {
                  setState(() {
                    selectedLanguage = newValue!;
                  });
                },
              ),

              const SizedBox(height: 12),

              // Privacy Policy
              _buildSettingsCard(
                title: "Privacy Policy",
                subtitle: "Review our privacy policy",
                icon: Icons.privacy_tip,
                iconColor: Colors.green,
                onTap: () {
                  // Future: Open Privacy Policy page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Privacy Policy - Coming soon!")),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Rate the App
              _buildSettingsCard(
                title: "Rate the App",
                subtitle: "Let us know your feedback",
                icon: Icons.star,
                iconColor: Colors.orange,
                onTap: () {
                  // Future: Implement rating feature
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Rate Us - Coming soon!")),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // General Settings Card
  Widget _buildSettingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        leading: Icon(icon, color: iconColor),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  // Dropdown Settings Card
  Widget _buildDropDownCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String dropdownValue,
    required List<String> dropdownItems,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        leading: Icon(icon, color: iconColor),
        trailing: DropdownButton<String>(
          value: dropdownValue,
          onChanged: onChanged,
          items: dropdownItems.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}

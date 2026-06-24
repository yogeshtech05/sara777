import 'package:flutter/foundation.dart'; // For @required if using older Dart, or just for key

class GameItem {
  final int id;
  final String name; // Original name from API
  final String type;
  final String image;
  final bool sessionSelection;
  String
  currentDisplayName; // Display name (initially original, then translated)

  GameItem({
    // Using Key for potential future use or consistency, though not strictly needed for a model
    Key? key,
    required this.id,
    required this.name,
    required this.type,
    required this.image,
    required this.sessionSelection,
    String?
    currentDisplayName, // Make optional in constructor for initial assignment
  }) : this.currentDisplayName =
           currentDisplayName ??
           name; // Default to original name if not provided

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      image: json['image'],
      sessionSelection: json['sessionSelection'] ?? false,
      // currentDisplayName is initialized in the constructor after fromJson is called
    );
  }

  // Method to update display name
  void updateDisplayName(String newName) {
    currentDisplayName = newName;
  }
}

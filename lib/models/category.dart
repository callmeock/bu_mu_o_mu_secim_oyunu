import 'package:cloud_firestore/cloud_firestore.dart';

/// Category model matching the new Firestore schema
class Category {
  final String id;
  final String name;
  final String type; // "quiz" | "tournament"
  final String mode; // "normal" | "daily"
  final String image;
  final List<String> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.mode,
    required this.image,
    required this.items,
    this.createdAt,
    this.updatedAt,
  });

  /// Parse Category from Firestore document
  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Parse name (default to docId if missing)
    final name = data['name'] as String? ?? doc.id;
    
    // Parse type (default to "quiz" if missing)
    final type = data['type'] as String? ?? 'quiz';
    
    // Parse mode (default to "normal" if missing)
    final mode = data['mode'] as String? ?? 'normal';
    
    // Parse image (default to empty string)
    final image = (data['image'] as String? ?? '').toString();
    
    // Parse items (default to empty list)
    final items = List<String>.from(data['items'] ?? const []);
    
    // Parse createdAt - handle both Timestamp and epoch (number)
    DateTime? createdAt;
    final createdAtValue = data['createdAt'];
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
    } else if (createdAtValue != null) {
      try {
        createdAt = (createdAtValue as Timestamp).toDate();
      } catch (_) {
        createdAt = null;
      }
    }
    
    // Parse updatedAt - handle both Timestamp and epoch (number)
    DateTime? updatedAt;
    final updatedAtValue = data['updatedAt'];
    if (updatedAtValue is Timestamp) {
      updatedAt = updatedAtValue.toDate();
    } else if (updatedAtValue is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtValue);
    } else if (updatedAtValue != null) {
      try {
        updatedAt = (updatedAtValue as Timestamp).toDate();
      } catch (_) {
        updatedAt = null;
      }
    }
    
    return Category(
      id: doc.id,
      name: name,
      type: type,
      mode: mode,
      image: image,
      items: items,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Convert Category to Map for Firestore (for updates if needed)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'mode': mode,
      'image': image,
      'items': items,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}


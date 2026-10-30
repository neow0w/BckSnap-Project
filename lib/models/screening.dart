import 'package:cloud_firestore/cloud_firestore.dart';

class Screening {
  final String id;
  final String userId;
  final double angle;
  final bool hasScoliosis;
  final bool hasPhoto;
  final DateTime createdAt;
  final Map<String, dynamic>? details; // levels and posture of the screening

  const Screening({
    required this.id,
    required this.userId,
    required this.angle,
    required this.hasScoliosis,
    required this.hasPhoto,
    required this.createdAt,
    this.details,
  });

  factory Screening.fromMap(String id, Map<String, dynamic> m) => Screening(
    id: id,
    userId: m['userId'] as String,
    angle: (m['angle'] as num).toDouble(),
    hasScoliosis: m['hasScoliosis'] == true,
    hasPhoto: m['hasPhoto'] == true,
    createdAt: m['createdAt'] is Timestamp
        ? (m['createdAt'] as Timestamp).toDate()
        : DateTime.now(),
    details: m['details'] is Map
        ? Map<String, dynamic>.from(m['details'] as Map)
        : null,
  );
}

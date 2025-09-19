import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized service for validating and filtering user documents
/// This prevents empty/invalid user entries from appearing throughout the app
class UserValidationService {
  /// Validates a single user document
  static bool isValidUser(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    try {
      final name = userData['name'];
      final email = userData['email'];
      final role = userData['role'];

      // Validate name
      if (name == null || name is! String || name.trim().isEmpty) {
        return false;
      }

      // Validate email
      if (email == null || email is! String || email.trim().isEmpty) {
        return false;
      }

      // Validate role
      if (role == null || role is! String || role.trim().isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates a QueryDocumentSnapshot
  static bool isValidUserDocument(QueryDocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) return false;
      return isValidUser(data as Map<String, dynamic>);
    } catch (e) {
      return false;
    }
  }

  /// Filters a list of QueryDocumentSnapshot to only include valid users
  static List<QueryDocumentSnapshot> filterValidUsers(List<QueryDocumentSnapshot> docs) {
    final validUsers = <QueryDocumentSnapshot>[];
    int totalProcessed = 0;
    int invalidCount = 0;

    for (final doc in docs) {
      totalProcessed++;

      if (isValidUserDocument(doc)) {
        validUsers.add(doc);
      } else {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          final name = data?['name'];
          final email = data?['email'];
          final role = data?['role'];
          print('Filtered invalid user ${doc.id}: name=$name, email=$email, role=$role');
        } catch (e) {
          print('Filtered invalid user ${doc.id}: Error reading data - $e');
        }
        invalidCount++;
      }
    }

    print('UserValidationService: Processed $totalProcessed users, filtered out $invalidCount invalid users, ${validUsers.length} valid users remaining');
    return validUsers;
  }

  /// Filters a stream of QuerySnapshot to only include valid users
  static Stream<List<QueryDocumentSnapshot>> getValidUsersStream(Stream<QuerySnapshot> usersStream) {
    return usersStream.map((snapshot) {
      return filterValidUsers(snapshot.docs);
    });
  }

  /// Gets all valid users from Firestore
  static Stream<List<QueryDocumentSnapshot>> getAllValidUsersStream() {
    return getValidUsersStream(
      FirebaseFirestore.instance.collection('Users').snapshots()
    );
  }

  /// Gets valid users filtered by role
  static Stream<List<QueryDocumentSnapshot>> getValidUsersByRoleStream(String role) {
    return getValidUsersStream(
      FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: role)
          .snapshots()
    );
  }

  /// Gets valid users filtered by multiple roles
  static Stream<List<QueryDocumentSnapshot>> getValidUsersByRolesStream(List<String> roles) {
    return getValidUsersStream(
      FirebaseFirestore.instance
          .collection('Users')
          .where('role', whereIn: roles)
          .snapshots()
    );
  }

  /// Helper method to get user display info safely
  static Map<String, String> getUserDisplayInfo(Map<String, dynamic> userData) {
    return {
      'name': userData['name']?.toString() ?? 'Unknown',
      'email': userData['email']?.toString() ?? 'No Email',
      'role': userData['role']?.toString() ?? 'No Role',
    };
  }

  /// Helper method to get user display info from document
  static Map<String, String> getUserDisplayInfoFromDoc(QueryDocumentSnapshot doc) {
    try {
      final userData = doc.data() as Map<String, dynamic>;
      return getUserDisplayInfo(userData);
    } catch (e) {
      return {
        'name': 'Error Loading User',
        'email': 'Invalid Data',
        'role': 'Unknown',
      };
    }
  }
}
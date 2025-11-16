// File: lib/models/subscription_slot.dart
import '../models/menu_model.dart';

/// Mewakili satu slot dalam langganan (misal: Hari 1 - Siang).
class SubscriptionSlot {
  final int day; // Hari ke- (1, 2, 3...)
  final String mealTime; // Misal: "Siang" atau "Malam"
  MenuModel? selectedMenu; // Menu yang dipilih (awalnya null)

  SubscriptionSlot({
    required this.day,
    required this.mealTime,
    this.selectedMenu,
  });

  /// Label yang akan ditampilkan di UI, misal: "Hari 1 - Siang"
  String get label {
    return 'Hari $day - $mealTime';
  }
}
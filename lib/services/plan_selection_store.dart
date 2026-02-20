import 'package:shared_preferences/shared_preferences.dart';

import '../subscription/plan_tier.dart';

class PlanSelectionStore {
  static const String key = 'selected_plan_tier';

  Future<PlanTier> loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    return planTierFromStorageValue(value);
  }

  Future<void> saveSelected(PlanTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, planTierToStorageValue(tier));
  }
}

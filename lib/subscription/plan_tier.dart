enum PlanTier { free, proMonthly, proYearly }

String planTierToStorageValue(PlanTier tier) {
  switch (tier) {
    case PlanTier.free:
      return 'free';
    case PlanTier.proMonthly:
      return 'pro_monthly';
    case PlanTier.proYearly:
      return 'pro_yearly';
  }
}

PlanTier planTierFromStorageValue(String? value) {
  switch (value) {
    case 'pro_monthly':
      return PlanTier.proMonthly;
    case 'pro_yearly':
      return PlanTier.proYearly;
    case 'free':
    default:
      return PlanTier.free;
  }
}

String planTierDisplayLabel(PlanTier tier) {
  switch (tier) {
    case PlanTier.free:
      return 'FREE';
    case PlanTier.proMonthly:
      return 'PRO (Monthly)';
    case PlanTier.proYearly:
      return 'PRO (Yearly)';
  }
}

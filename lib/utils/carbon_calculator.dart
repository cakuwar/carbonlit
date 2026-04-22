/// Grid emission factor for Peninsular Malaysia (kg CO₂e per kWh).
const double gridEmissionFactor = 0.740;

/// Calculate carbon emission from energy consumption.
///
/// [energy] — the amount of energy consumed in kWh.
///
/// Returns the estimated carbon emission in kg CO₂e.
/// Formula: emission = energy (kWh) × 0.740 (kg CO₂e/kWh)
double calculateCarbonEmission(double energy) {
  return energy * gridEmissionFactor;
}

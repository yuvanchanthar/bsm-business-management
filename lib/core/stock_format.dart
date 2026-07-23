/// Formats an inventory quantity preserving decimals where they exist.
///
/// Rules:
///   100.0  → "100"   (whole number: no decimals)
///   74.5   → "74.5"  (one decimal)
///   99.25  → "99.3"  (rounded to one decimal)
///   0.5    → "0.5"
///
/// Use this everywhere inventory stock, threshold, or quantity values
/// are displayed — never use toStringAsFixed(0) for stock values.
String fmtStock(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

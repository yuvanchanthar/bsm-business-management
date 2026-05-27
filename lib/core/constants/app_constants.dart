/// Application-wide constants used across the invoice template system.
class AppConstants {
  AppConstants._();

  // ── SharedPreferences Keys ─────────────────────────────────────────────────
  static const String kDefaultTemplateKey = 'default_invoice_template_id';

  // ── Template IDs ──────────────────────────────────────────────────────────
  static const String kTemplateClassic   = 'classic';
  static const String kTemplateModern    = 'modern';
  static const String kTemplateGst       = 'gst';
  static const String kTemplateDark      = 'dark';
  static const String kTemplateCorporate = 'corporate';
}

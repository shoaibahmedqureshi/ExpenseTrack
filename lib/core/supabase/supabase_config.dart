class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://xgavxbuezmivnseyhkye.supabase.co';
  static const String anonKey = 'sb_publishable_cTHDiUVcracNw3eF9w5ATQ_Pd7Afi5Y';

  /// Email confirmation / password reset landing page, registered in
  /// Supabase dashboard → Authentication → URL Configuration → Redirect
  /// URLs. Hosted on GitHub Pages (Supabase Storage serves HTML as
  /// text/plain with a locked-down CSP for XSS protection, so it can't
  /// render this page) so it works on any device, even one that doesn't
  /// have the app installed; the page itself attempts the
  /// io.supabase.expensetracker:// deep link as a bonus when opened on the
  /// same device as the app.
  static const String redirectUrl =
      'https://shoaibahmedqureshi.github.io/photoapppoc/confirm.html';
}

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://xgavxbuezmivnseyhkye.supabase.co';
  static const String anonKey = 'sb_publishable_cTHDiUVcracNw3eF9w5ATQ_Pd7Afi5Y';

  /// Deep-link redirect URI registered in Supabase dashboard →
  /// Authentication → URL Configuration → Redirect URLs
  static const String redirectUrl = 'io.supabase.expensetracker://login-callback';
}

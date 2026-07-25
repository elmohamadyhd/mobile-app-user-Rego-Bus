/// CMS page slugs and go_router paths. Lives in shared so booking widgets
/// can navigate without importing `features/pages`.
abstract final class CmsPagePaths {
  static const termsSlug = 'terms-and-conditions';
  static const privacySlug = 'privacy-and-policy';

  static const terms = '/pages/$termsSlug';
  static const privacy = '/pages/$privacySlug';

  static String detail(String slug) => '/pages/$slug';
}

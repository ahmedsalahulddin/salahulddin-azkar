import '../services/app_locale.dart';

/// Returns the string for [key] in the current app locale.
String t(String key) {
  final map = AppLocale.isEn ? _en : _ar;
  return map[key] ?? key;
}

// ─── Arabic (default) ──────────────────────────────────────────────────────

const _ar = <String, String>{
  // Bottom navigation
  'nav.adhkar': 'أذكاري',
  'nav.home': 'الرئيسية',
  'nav.account': 'حسابي',

  // Search bar
  'search.label': 'بحث شامل',
  'search.hint': 'ابحث في كل أقسام التطبيق…',

  // Home shelf: Quran
  'shelf.quran.title': 'القرآن الكريم',
  'card.mushaf.title': 'القرآن الكريم',
  'card.mushaf.sub': 'صفحات',
  'card.translation.title': 'ترجمات القرآن',
  'card.translation.sub': 'بلغات متعددة',
  'card.recitation.title': 'تلاوة وتدبّر',
  'card.recitation.sub': 'آية آية مع التفسير',
  'card.memtest.title': 'اختبار الحفظ',
  'card.memtest.sub': 'أربع طرق للسؤال',
  'card.radio.title': 'الإذاعة',
  'card.radio.sub': 'القاهرة والسعودية وثلاث غيرها',
  'card.listen.title': 'الاستماع الدائم',
  'card.listen.sub': 'المصحف كاملاً بلا توقّف',

  // Home shelf: Adhkar
  'shelf.adhkar.title': 'الأذكار',
  'card.sahih.title': 'صحيح الأذكار',
  'card.sahih.sub': 'حصن المسلم',
  'card.umrah.title': 'أدعية العمرة',
  'card.umrah.sub': 'من الميقات للتحلّل',
  'card.tasbih.title': 'عداد التسبيح',
  'card.tasbih.sub': 'سبّح واحتسب',
  'adhkar.countSuffix': 'ذكر',

  // Home shelf: Lessons / Cards / Library (titles only)
  'shelf.lessons.title': 'الدروس',
  'shelf.cards.title': 'كروت المعايدة',
  'shelf.library.title': 'الكتب والأحاديث',

  // Account screen
  'account.title': 'حسابي والإعدادات',
  'account.guest': 'تقرأ كضيف',
  'account.guestNote': 'التطبيق يعمل كاملاً بدون حساب،\nوكل ما تحفظه محفوظ على جهازك.',
  'account.signInSoon': 'الدخول بحساب جوجل — قريباً',
  'account.signInPrompt': 'سجّل الدخول لتنتقل مفضلتك وعلاماتك\nوموضع قراءتك بين أجهزتك.',
  'account.signOut': 'تسجيل الخروج',
  'account.signOutMsg': 'ستبقى أذكارك المحفوظة على هذا الجهاز.',
  'account.signOutConfirm': 'خروج',
  'account.delete': 'حذف الحساب نهائياً',
  'account.deleting': 'جاري الحذف…',
  'account.deleteTitle': 'حذف الحساب نهائياً',
  'account.deleteMsg': 'سيُحذف حسابك وكل ما يخصّه من خوادمنا حذفاً لا رجعة فيه.',
  'account.deleteNote': 'أذكارك المحفوظة وعلاماتك على هذا الجهاز تبقى كما هي — يمحوها حذف التطبيق.',
  'account.deleteConfirm': 'اكتب كلمة «حذف» للتأكيد:',
  'account.deleteWord': 'حذف',
  'account.deleteBtn': 'احذف حسابي',
  'account.deleteDone': 'تم حذف حسابك',
  'account.deleteFail': 'تعذّر الحذف — حاول مرة أخرى أو راسلنا',
  'account.signInFail': 'تعذّر تسجيل الدخول — حاول مرة أخرى',
  'account.cancel': 'إلغاء',
  'account.continue': 'متابعة',
  'account.lastConfirm': 'تأكيد أخير',
  'account.optional': 'اختياري — يمكنك المتابعة كضيف',
  'account.adminSection': 'الإدارة',
  'account.adminTitle': 'إدارة الأقسام',
  'account.adminSub': 'أظهِر وأخفِ ورتّب أقسام الشاشة الرئيسية',
  'account.aboutSection': 'عن التطبيق',
  'account.version': 'الإصدار',
  'account.sources': 'المصادر والحقوق',
  'account.sourcesSub': 'من أين جاء كل نصّ وصوت وخطّ في التطبيق',
  'account.aboutText': 'نص المصحف: مجمع الملك فهد لطباعة المصحف الشريف\nالأذكار: حصن المسلم — سعيد بن علي القحطاني',
  'account.sync': 'مزامنة علاماتك ومفضّلتك',
  'account.syncNever': 'لم تُزامَن بعد على هذا الجهاز',
  'account.syncLast': 'آخر مزامنة',
  'account.syncNow': 'زامن الآن',
  'account.syncDone': 'تمت المزامنة',
  'account.syncFail': 'تعذّرت المزامنة الآن',
  'account.am': 'ص',
  'account.pm': 'م',
};

// ─── English ───────────────────────────────────────────────────────────────

const _en = <String, String>{
  // Bottom navigation
  'nav.adhkar': 'My Adhkar',
  'nav.home': 'Home',
  'nav.account': 'Account',

  // Search bar
  'search.label': 'Search',
  'search.hint': 'Search all sections…',

  // Home shelf: Quran
  'shelf.quran.title': 'Holy Quran',
  'card.mushaf.title': 'Holy Quran',
  'card.mushaf.sub': 'Pages',
  'card.translation.title': 'Quran Translations',
  'card.translation.sub': 'Multiple languages',
  'card.recitation.title': 'Recitation',
  'card.recitation.sub': 'Verse by verse with tafsir',
  'card.memtest.title': 'Memory Test',
  'card.memtest.sub': 'Four question types',
  'card.radio.title': 'Radio',
  'card.radio.sub': 'Egyptian, Saudi & more',
  'card.listen.title': 'Continuous Listening',
  'card.listen.sub': 'Full Quran, uninterrupted',

  // Home shelf: Adhkar
  'shelf.adhkar.title': 'Adhkar',
  'card.sahih.title': 'Authentic Adhkar',
  'card.sahih.sub': 'Hisn Al-Muslim',
  'card.umrah.title': 'Umrah Supplications',
  'card.umrah.sub': 'From miqat to tahallul',
  'card.tasbih.title': 'Tasbih Counter',
  'card.tasbih.sub': 'Glorify & be rewarded',
  'adhkar.countSuffix': 'adhkar',

  // Home shelf: Lessons / Cards / Library (titles only)
  'shelf.lessons.title': 'Lessons',
  'shelf.cards.title': 'Greeting Cards',
  'shelf.library.title': 'Books & Hadith',

  // Account screen
  'account.title': 'Account & Settings',
  'account.guest': 'Browsing as guest',
  'account.guestNote': 'The app works fully without an account.\nEverything you save stays on your device.',
  'account.signInSoon': 'Sign in with Google — coming soon',
  'account.signInPrompt': 'Sign in to sync your favorites,\nbookmarks and reading position across devices.',
  'account.signOut': 'Sign out',
  'account.signOutMsg': 'Your saved adhkar will remain on this device.',
  'account.signOutConfirm': 'Sign out',
  'account.delete': 'Delete account permanently',
  'account.deleting': 'Deleting…',
  'account.deleteTitle': 'Delete account permanently',
  'account.deleteMsg': 'Your account and all its data will be permanently deleted from our servers.',
  'account.deleteNote': 'Your saved adhkar and bookmarks on this device remain — they are only removed if you uninstall the app.',
  'account.deleteConfirm': 'Type the word "delete" to confirm:',
  'account.deleteWord': 'delete',
  'account.deleteBtn': 'Delete my account',
  'account.deleteDone': 'Your account has been deleted',
  'account.deleteFail': 'Deletion failed — try again or contact us',
  'account.signInFail': 'Sign in failed — please try again',
  'account.cancel': 'Cancel',
  'account.continue': 'Continue',
  'account.lastConfirm': 'Final confirmation',
  'account.optional': 'Optional — you can continue as a guest',
  'account.adminSection': 'Admin',
  'account.adminTitle': 'Manage Sections',
  'account.adminSub': 'Show, hide and reorder home screen sections',
  'account.aboutSection': 'About',
  'account.version': 'Version',
  'account.sources': 'Sources & Credits',
  'account.sourcesSub': 'Sources for all text, audio and fonts in the app',
  'account.aboutText': 'Quran text: King Fahd Complex for the Printing of the Holy Quran\nAdhkar: Hisn Al-Muslim — Sa\'eed ibn Ali Al-Qahtani',
  'account.sync': 'Sync your bookmarks & favorites',
  'account.syncNever': 'Not yet synced on this device',
  'account.syncLast': 'Last synced',
  'account.syncNow': 'Sync now',
  'account.syncDone': 'Synced',
  'account.syncFail': 'Sync failed, try again',
  'account.am': 'AM',
  'account.pm': 'PM',
};

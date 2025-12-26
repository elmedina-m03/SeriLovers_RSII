import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Language provider for managing app language
class LanguageProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _languageKey = 'app_language';
  
  String _currentLanguage = 'English';
  
  String get currentLanguage => _currentLanguage;
  
  /// Available languages
  static const List<String> availableLanguages = ['English', 'Bosnian'];
  
  /// Translations map
  static const Map<String, Map<String, String>> translations = {
    'English': {
      'settings': 'Settings',
      'languagePreferences': 'Language Preferences',
      'appLanguage': 'App Language',
      'languageRestartNote': 'Note: Language changes will be applied after app restart.',
      'passwordChange': 'Password Change',
      'privacySettings': 'Privacy Settings',
      'currentPassword': 'Current Password',
      'newPassword': 'New Password',
      'confirmPassword': 'Confirm New Password',
      'changePassword': 'Change Password',
      'passwordRequired': 'Password is required',
      'passwordMinLength': 'Password must be at least 8 characters',
      'confirmPasswordRequired': 'Please confirm your new password',
      'passwordsDoNotMatch': 'Passwords do not match',
      'newPasswordMissing': 'Please enter a new password',
      'currentPasswordMissing': 'Current password is required',
      'passwordChangedSuccess': 'Password changed successfully',
      'passwordChangedFailed': 'Failed to change password. Please check your current password.',
      'passwordChangedError': 'Error changing password',
      'profileVisibility': 'Profile Visibility',
      'activityVisibility': 'Activity Visibility',
      'emailNotifications': 'Email Notifications',
      'profileVisibleOn': 'Profile is now visible to others',
      'profileVisibleOff': 'Profile is now private',
      'activityVisibleOn': 'Activity is now visible to others',
      'activityVisibleOff': 'Activity is now private',
      'emailNotificationsEnabled': 'Email notifications enabled',
      'emailNotificationsDisabled': 'Email notifications disabled',
      'status': 'Status',
      'toDo': 'To do',
      'inProgress': 'In progress',
      'finished': 'Finished',
      'statistics': 'Statistics',
      'series': 'SERIES',
      'episodes': 'EPISODES',
      'reviews': 'REVIEWS',
      'totalHours': 'Total Hours',
      'hours': 'hours',
      'watchedIn': 'watched in',
      'mostWatchedGenre': 'Most Watched Genre',
      'allowOthersToViewProfile': 'Allow others to view your profile',
      'showWatchHistory': 'Show your watch history and ratings',
      'receiveEmailUpdates': 'Receive email updates and notifications',
    },
    'Bosnian': {
      'settings': 'Postavke',
      'languagePreferences': 'Jezičke Postavke',
      'appLanguage': 'Jezik Aplikacije',
      'languageRestartNote': 'Napomena: Promjene jezika će biti primijenjene nakon ponovnog pokretanja aplikacije.',
      'passwordChange': 'Promjena Lozinke',
      'privacySettings': 'Postavke Privatnosti',
      'currentPassword': 'Trenutna Lozinka',
      'newPassword': 'Nova Lozinka',
      'confirmPassword': 'Potvrdi Novu Lozinku',
      'changePassword': 'Promijeni Lozinku',
      'passwordRequired': 'Lozinka je obavezna',
      'passwordMinLength': 'Lozinka mora imati najmanje 8 karaktera',
      'confirmPasswordRequired': 'Potvrdite novu lozinku',
      'passwordsDoNotMatch': 'Lozinke se ne podudaraju',
      'newPasswordMissing': 'Unesite novu lozinku',
      'currentPasswordMissing': 'Trenutna lozinka je obavezna',
      'passwordChangedSuccess': 'Lozinka je uspješno promijenjena',
      'passwordChangedFailed': 'Promjena lozinke nije uspjela. Provjerite trenutnu lozinku.',
      'passwordChangedError': 'Greška prilikom promjene lozinke',
      'profileVisibility': 'Vidljivost Profila',
      'activityVisibility': 'Vidljivost Aktivnosti',
      'emailNotifications': 'Email Obavještenja',
      'profileVisibleOn': 'Profil je sada vidljiv drugima',
      'profileVisibleOff': 'Profil je sada privatan',
      'activityVisibleOn': 'Aktivnost je sada vidljiva drugima',
      'activityVisibleOff': 'Aktivnost je sada privatna',
      'emailNotificationsEnabled': 'Email obavještenja su omogućena',
      'emailNotificationsDisabled': 'Email obavještenja su onemogućena',
      'status': 'Status',
      'toDo': 'Za raditi',
      'inProgress': 'U toku',
      'finished': 'Završeno',
      'statistics': 'Statistika',
      'series': 'SERIJE',
      'episodes': 'EPIZODE',
      'reviews': 'RECENZIJE',
      'totalHours': 'Ukupno Satova',
      'hours': 'sati',
      'watchedIn': 'gledano u',
      'mostWatchedGenre': 'Najgledaniji Žanr',
      'allowOthersToViewProfile': 'Dozvoli drugima da vide vaš profil',
      'showWatchHistory': 'Prikaži vašu istoriju gledanja i ocene',
      'receiveEmailUpdates': 'Primaj email ažuriranja i obavještenja',
    },
  };
  
  LanguageProvider() {
    _loadLanguage();
  }
  
  /// Load saved language from storage
  Future<void> _loadLanguage() async {
    try {
      final savedLanguage = await _storage.read(key: _languageKey);
      if (savedLanguage != null && availableLanguages.contains(savedLanguage)) {
        _currentLanguage = savedLanguage;
        notifyListeners();
      }
    } catch (e) {
      // Use default language if loading fails
      _currentLanguage = 'English';
    }
  }
  
  /// Change language
  Future<void> setLanguage(String language) async {
    if (!availableLanguages.contains(language)) {
      return;
    }
    
    _currentLanguage = language;
    await _storage.write(key: _languageKey, value: language);
    notifyListeners();
  }
  
  /// Get translated text
  String translate(String key) {
    return translations[_currentLanguage]?[key] ?? 
           translations['English']?[key] ?? 
           key;
  }
  
  /// Get translated text with fallback
  String translateWithFallback(String key, String fallback) {
    return translations[_currentLanguage]?[key] ?? 
           translations['English']?[key] ?? 
           fallback;
  }
}


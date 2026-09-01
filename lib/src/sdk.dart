// ignore_for_file:implementation_imports
import 'package:intl/intl.dart';
import 'package:intl/src/intl_helpers.dart';
import 'package:localazy_sdk/src/cdn/api/localazy_cdn_api.dart';
import 'package:localazy_sdk/src/cdn/localazy_manager.dart';
import 'package:localazy_sdk/src/cdn/proxy/proxy.dart';

import 'cdn/models/translations_update_result.dart';
import 'common/util/util.dart';
import 'sdk_exception.dart';

/// The Localizely SDK.
class Localazy {
  static String? _cdnId;
  static String? _currentLocale;
  static String? _fileName;
  static String? _cacheFolder;

  Localazy._();

  /// Initializes Localizely SDK.
  ///
  /// Values for [sdkToken] and [distributionId] are generated on the Localizely platform.
  static void init(String cdnId, {required String cacheFolder, String? locale, String? fileName}) {
    _cdnId = cdnId;
    _cacheFolder = cacheFolder;
    _currentLocale = locale != null ? Intl.shortLocale(locale) : null;
    _fileName = fileName ?? 'intl.arb';

    messageLookup = MessageLookupProxy.from(messageLookup);
  }

  static void setLocale(String locale) {
    _currentLocale = Intl.shortLocale(locale);
  }

  static void setFileName(String fileName) {
    _fileName = fileName;
  }

  /// Sets the application version.
  ///
  /// Use this to explicitly set the application version, or in cases when automatic detection is not possible (e.g. Flutter web apps).
  /// Throws [SdkException] in case provided value does not comply with semantic versioning specification.
  static void setAppVersion(String version) {
    if (!Util.isValidSemanticVersion(version)) {
      throw SdkException(
          'Localizely SDK expects a valid version of the app which complies with semantic versioning specification.');
    }

    LocalazyManager.appBuildNumber = version;
  }

  /// Updates existing translations with the ones from the Localizely platform.
  ///
  /// This method should be called after localization delegates initialization.
  ///
  /// ```
  /// Localizely.updateTranslations().then((response) => setState(() => print('Translations fetched')), onError: (error) => print('Error occurred'));
  /// ```
  ///
  /// Throws [SdkException] in case sdk token, distribution id, metadata, or application version is not set or can't be detected.
  /// Throws [ApiException] in case of http request failure.
  static Future<TranslationsUpdateResult> updateTranslations() async {
    final locale = Intl.shortLocale(_currentLocale ?? Intl.getCurrentLocale());

    if (_cdnId == null) {
      throw SdkException(
          'Localazy CDN ID has not been initialized or SDK token has not been provided during SDK initialization.');
    }

    var appBuildNumber = LocalazyManager.appBuildNumber ?? await Util.getAppBuildNumber();
    if (appBuildNumber == null) {
      throw SdkException(
          "The application version can't be detected. Please use the 'setAppVersion' method for setting up the required parameter.");
    }

    if (!LocalazyManager.hasReleaseData) {
      final config = await LocalazyCdnApi.getCachedData(
        cdnId: _cdnId!,
        fileName: _fileName!,
        languageCode: locale,
        cacheFolder: _cacheFolder!,
      );

      LocalazyManager.config = config;
    }

    try {
      final config = await LocalazyCdnApi.syncTranslations(
        cdnId: _cdnId!,
        fileName: _fileName!,
        languageCode: locale,
        cacheFolder: _cacheFolder!,
      );

      LocalazyManager.config = config;
    } catch (ex) {}

    return TranslationsUpdateResult(0, 1);
  }

  /// Removes all cached Localazy data (remote config and downloaded translations)
  /// and drops the translations that are currently loaded in memory.
  ///
  /// After this call the app falls back to the translations bundled with it,
  /// until [updateTranslations] is called again.
  ///
  /// ```
  /// await Localazy.clearCache();
  /// await Localazy.updateTranslations();
  /// ```
  ///
  /// Throws [SdkException] in case the SDK has not been initialized.
  static Future<void> clearCache() async {
    _assertInitialized();

    await LocalazyCdnApi.clearCache(
      cdnId: _cdnId!,
      cacheFolder: _cacheFolder!,
    );

    LocalazyManager.clear();
  }

  /// Removes the cached translations from the disk.
  ///
  /// By default the translations of every locale of the current file are removed.
  /// Pass [locale] and/or [fileName] to narrow it down to a specific cached file.
  /// The cached remote config is kept.
  ///
  /// Set [keepLoadedTranslations] to `true` to keep the translations that are
  /// already loaded in memory active until the next [updateTranslations] call.
  ///
  /// Throws [SdkException] in case the SDK has not been initialized.
  static Future<void> clearTranslations({
    String? locale,
    String? fileName,
    bool keepLoadedTranslations = false,
  }) async {
    _assertInitialized();

    await LocalazyCdnApi.clearCache(
      cdnId: _cdnId!,
      cacheFolder: _cacheFolder!,
      fileName: fileName ?? _fileName,
      languageCode: locale != null ? Intl.shortLocale(locale) : null,
    );

    if (!keepLoadedTranslations) {
      LocalazyManager.clear();
    }
  }

  /// Drops the translations that are currently loaded in memory without touching the cache.
  ///
  /// The app falls back to the translations bundled with it, until
  /// [updateTranslations] is called again.
  static void clearLoadedTranslations() {
    LocalazyManager.clear();
  }

  static void _assertInitialized() {
    if (_cdnId == null || _cacheFolder == null) {
      throw SdkException("Localazy SDK has not been initialized. Please call the 'init' method first.");
    }
  }
}

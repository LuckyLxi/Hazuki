import '../../l10n/app_localizations.dart';
import '../../services/translation/translation_failure.dart';

String translationFailureMessage(
  AppLocalizations strings,
  TranslationFailureKind kind,
) => switch (kind) {
  TranslationFailureKind.cancelled => strings.translationCancelled,
  TranslationFailureKind.unauthorized => strings.translationUnauthorized,
  TranslationFailureKind.quotaExceeded => strings.translationQuotaExceeded,
  TranslationFailureKind.rateLimited => strings.translationRateLimited,
  TranslationFailureKind.network => strings.translationNetwork,
  TranslationFailureKind.badResponse => strings.translationBadResponse,
  TranslationFailureKind.server => strings.translationServer,
  TranslationFailureKind.unknown => strings.translationUnknown,
  TranslationFailureKind.detectorUnavailable =>
    strings.translationDetectorUnavailable,
  TranslationFailureKind.detectorFailed => strings.translationDetectorFailed,
};

import 'share_outcome.dart';

/// Non-web platforms have no Web Share API; the caller falls back to copy.
Future<ShareOutcome> shareLink(
        {required String text, required String url}) async =>
    ShareOutcome.unsupported;

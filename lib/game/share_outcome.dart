/// Result of attempting a native share.
enum ShareOutcome {
  /// The native share sheet was shown (and the share completed or was
  /// cancelled by the user — either way, don't fall back).
  shown,

  /// No native share is available (e.g. desktop browser); the caller should
  /// fall back to copying the link.
  unsupported,
}

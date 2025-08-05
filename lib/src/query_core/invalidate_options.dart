class InvalidateOptions {
  final bool throwOnError;
  final bool cancelRefetch;

  const InvalidateOptions({
    this.throwOnError = false,
    this.cancelRefetch = true,
  });
}
Future<T> retryCall<T>(Future<T> Function() fn) async {
  int attempts = 0;
  const maxAttempts = 2;
  const delay = Duration(milliseconds: 350);

  while (true) {
    try {
      return await fn();
    } catch (e) {
      attempts++;
      if (attempts >= maxAttempts) {
        rethrow;
      }
      await Future.delayed(delay);
    }
  }
}
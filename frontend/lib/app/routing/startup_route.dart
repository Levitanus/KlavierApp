class StartupRoute {
  const StartupRoute._({
    this.resetPasswordToken,
    this.registrationToken,
  });

  final String? resetPasswordToken;
  final String? registrationToken;

  bool get showsResetPassword =>
      resetPasswordToken != null && resetPasswordToken!.isNotEmpty;
  bool get showsRegistration =>
      registrationToken != null && registrationToken!.isNotEmpty;

  static StartupRoute fromUri(Uri uri) {
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'reset-password') {
      return StartupRoute._(resetPasswordToken: uri.pathSegments[1]);
    }
    if (uri.path == '/register' && uri.queryParameters.containsKey('token')) {
      return StartupRoute._(registrationToken: uri.queryParameters['token']);
    }
    return const StartupRoute._();
  }
}

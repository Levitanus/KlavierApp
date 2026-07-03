import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferences {
  static const consentAcceptedKey = 'consent_accepted_v1';

  Future<void> setConsentAccepted(bool accepted) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(consentAcceptedKey, accepted);
  }

  Future<bool> isConsentAccepted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(consentAcceptedKey) ?? false;
  }
}

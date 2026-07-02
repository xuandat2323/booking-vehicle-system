import 'package:flutter/foundation.dart';

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Listenable listenable) {
    listenable.addListener(notifyListeners);
  }
}

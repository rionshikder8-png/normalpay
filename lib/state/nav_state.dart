import 'package:flutter/foundation.dart';

/// Selected bottom-navigation tab of the app shell.
///
/// 0 Dashboard, 1 Transactions, 2 Notifications, 3 Gateways, 4 Settings.
/// Kept outside [AppState] so screens (and notification deep links) can switch
/// tabs without owning the shell.
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

const int dashboardTab = 0;
const int transactionsTab = 1;
const int notificationsTab = 2;
const int gatewaysTab = 3;
const int settingsTab = 4;

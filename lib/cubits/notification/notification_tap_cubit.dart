import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/notification_target.dart';

/// Holds a tapped notification until MainLayout opens it. App-wide, so a
/// tap that arrives before sign-in (or while the app was closed) waits
/// until the user is in the app.
class NotificationTapCubit extends Cubit<NotificationTarget?> {
  StreamSubscription<NotificationTarget>? _subscription;

  NotificationTapCubit({
    required Stream<NotificationTarget> taps,
    NotificationTarget? launchTarget,
  }) : super(launchTarget) {
    _subscription = taps.listen(emit);
  }

  /// MainLayout has opened (or is opening) the pending target.
  void handled() => emit(null);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

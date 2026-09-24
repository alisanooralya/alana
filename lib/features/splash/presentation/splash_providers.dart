import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` bila splash sudah tampil minimal (~800ms).
///
/// Redirect menahan di `/splash` sampai flag ini true DAN status
/// sesi diketahui, agar tidak berkedip.
final splashSiapProvider = StateProvider<bool>((ref) => false);

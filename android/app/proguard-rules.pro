# UCrop (dipakai image_cropper): activity dideklarasikan lewat manifest
# merger, jadi R8 tidak boleh me-rename class-nya. Tanpa ini, release
# build crash ActivityNotFoundException saat crop dibuka.
-keep class com.yalantis.ucrop.** { *; }
-keep class com.yalantis.ucrop.model.** { *; }
-keep class com.yalantis.ucrop.view.** { *; }

# flutter_local_notifications: receiver di bawah dideklarasikan manual di
# AndroidManifest (plugin tidak membawa declaration sendiri), jadi wajib
# di-keep agar pengingat terjadwal dan boot receiver tetap ketemu sistem.
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }

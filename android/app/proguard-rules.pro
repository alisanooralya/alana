# UCrop (dipakai image_cropper): activity dideklarasikan lewat manifest
# merger, jadi R8 tidak boleh me-rename class-nya. Tanpa ini, release
# build crash ActivityNotFoundException saat crop dibuka.
-keep class com.yalantis.ucrop.** { *; }
-keep class com.yalantis.ucrop.model.** { *; }
-keep class com.yalantis.ucrop.view.** { *; }

# flutter_local_notifications: receiver dideklarasikan manual di
# AndroidManifest (plugin tidak membawa declaration sendiri), dan
# NotificationDetails diserialisasi lewat Gson di jalur platform-channel.
# R8 me-rename kelas models.** hanya merusak build release, jadi keep satu
# paket penuh, bukan receiver per kelas.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Metadata yang dibuang R8 dibutuhkan serialisasi reflektif (Gson) dan
# resolusi callback. Flutter hanya menyediakannya sebagian lewat default
# file, jadi bergantung pada itu rapuh.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Catatan: firebase_core/firebase_messaging sudah membawa consumer rules
# sendiri. Kalau nanti ditambah firebase_crashlytics atau paket FlutterFire
# lain, cek dulu apakah rules-nya ikut terbawa.

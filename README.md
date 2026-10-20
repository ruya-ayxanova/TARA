# Infinity Browser

Flutter ile yazılmış, Android ve iOS için tarayıcı: sekmeler, gizli mod, hızlı arama,
reklam engelleyici ve sayfadaki ses/video dosyalarını indirme.

## Yerelde çalıştırma
```
flutter create --platforms=android,ios --project-name infinity_browser .
# android/app/src/main/AndroidManifest.xml içine, <application> öncesine ekle:
# <uses-permission android:name="android.permission.INTERNET"/>
flutter pub get
flutter run
```

## GitHub'da APK üretme
Repoya yükleyince **Actions → Build APK** otomatik çalışır; bitince
"infinity-browser-apk" çıktısından APK'yı indirirsiniz.

## Not
Yalnızca doğrudan dosya bağlantılarını (mp3, mp4 vb.) indirir. Telifli içerikleri
indirirken ilgili sitenin kullanım şartlarına uyun.

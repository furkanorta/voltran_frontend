Voltran AI Görüntü Düzenleyici - ÖN YÜZ (Frontend)
Bu depo, Fal AI'ın görüntüden-görüntüye (Image-to-Image) dönüştürme servisi için geliştirilmiş web tabanlı kullanıcı arayüzünü (UI) içerir. Uygulama, Flutter (Dart) kullanılarak geliştirilmiş ve Firebase Hosting üzerinden yayımlanmıştır.

🚀 Canlı Uygulama
Uygulamanın çalışan versiyonuna bu adresten ulaşabilirsiniz:
https://voltran-d0d69.web.app

🛠️ Teknoloji Yığını
Çerçeve: Flutter (3.x)

Dil: Dart

Bağımlılıklar: http (API çağrıları için), file_picker (dosya yükleme için)

Barındırma: Firebase Hosting

⚙️ Kurulum ve Başlatma (Geliştirme Ortamı)
Bu uygulamayı yerel ortamınızda çalıştırmak için:

Flutter SDK yüklü olduğundan emin olun.

Depoyu klonlayın:

git clone https://github.com/furkanorta/voltran_frontend
cd voltran_frontend

Bağımlılıkları yükleyin:

flutter pub get

Uygulamayı web modunda başlatın:

flutter run -d chrome

🔗 Backend Bağlantısı
Uygulama, tüm AI işlemleri ve Fal AI anahtar yönetimi için ayrı bir Backend servisine güvenir. Backend URL'si, lib/main.dart dosyası içindeki backendUrl değişkeninde tanımlanmıştır.

Backend Servisi: https://github.com/furkanorta/voltran_backend

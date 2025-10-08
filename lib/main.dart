import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
// Web indirme için gerekli kütüphane (Web dışındaki platformlarda hata vermemesi için koşullu import)
import 'dart:html' as html;

void main() {
  // Uygulamanın çalıştırılması
  runApp(const MyApp());
}

// Global Renk Paleti Tanımları
const Color primaryColor = Color(0xFF1976D2); // Koyu Mavi
const Color accentColor = Color(0xFF4CAF50); // Yeşil (Dönüştür butonu)
const Color errorColor = Color(0xFFD32F2F); // Kırmızı
const Color textColor = Color(0xFF263238); // Koyu Gri

/// Geçmişteki bir düzenleme kaydını temsil eden model sınıfı
class ImageHistoryItem {
  final String originalImageUrl; // Orijinal görselin URL'si veya bilgisi (Şu an için bytes tutmayacağız, sadece prompt ve sonuç)
  final String prompt;
  final String resultImageUrl; // Düzenlenmiş görselin URL'si
  final DateTime timestamp;

  ImageHistoryItem({
    required this.originalImageUrl,
    required this.prompt,
    required this.resultImageUrl,
    required this.timestamp
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voltran AI Image Editor',
      debugShowCheckedModeBanner: false, // Debug bandını kaldır
      theme: ThemeData(
        // Tema Renkleri
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
            .copyWith(secondary: accentColor),
        // Font stili
        fontFamily: 'Roboto',
        // Card ve ElevatedButton'lara hafif gölge ekle
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        // Uygulama genelinde adaptif görsel yoğunluk
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ImageEditorPage(),
    );
  }
}

class ImageEditorPage extends StatefulWidget {
  const ImageEditorPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ImageEditorPageState createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  Uint8List? _originalImageBytes;
  Uint8List? _editedImageBytes;
  String? _downloadImageUrl;
  String _prompt = '';
  bool _isLoading = false;
  String _errorMessage = '';

  // Yeni: Düzenleme geçmişini tutacak liste
  final List<ImageHistoryItem> _imageHistory = [];
  // Orijinal görselin URL'si (geçmişe kaydetmek için)
  String? _originalImageBase64;

  // Prompt Controller'ı
  final TextEditingController _promptController = TextEditingController();

  // Canlı Render URL'niz
  final String backendUrl = 'https://voltran-backend.onrender.com/api/generate';

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // Resim seçme
  Future<void> pickImage() async {
    setState(() {
      _errorMessage = '';
      // İstenen Düzeltme: Yeni resim seçildiğinde _imageHistory.clear() satırı kaldırıldı.
      // Geçmiş artık korunacak.
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _originalImageBytes = result.files.single.bytes;
        // Base64 formatında stringi kaydedelim (basit bir temsil için)
        _originalImageBase64 = base64Encode(_originalImageBytes!);
        _editedImageBytes = null;
        _downloadImageUrl = null;
      });
    }
  }

  // İndirme İşlemi (Web için)
  Future<void> downloadImage() async {
    if (_downloadImageUrl == null) {
      setState(() => _errorMessage = 'İndirilecek bir görsel bulunamadı.');
      return;
    }

    try {
      final response = await http.get(Uri.parse(_downloadImageUrl!));
      if (response.statusCode == 200) {
        final blob = response.bodyBytes;

        // Web tarayıcısında indirme tetikleme (dart:html kullanılır)
        final url = html.Url.createObjectUrlFromBlob(html.Blob([blob]));
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "ai_image_edit_${DateTime.now().millisecondsSinceEpoch}.png")
          ..click();
        html.Url.revokeObjectUrl(url); // Kaynağı temizle

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Görsel başarıyla indirilmeye başlandı.')),
          );
        }

      } else {
        setState(() => _errorMessage = 'Görsel indirilemedi: HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'İndirme sırasında hata oluştu: ${e.toString()}');
    }
  }

  // Generate butonu
  Future<void> generateImage() async {
    final trimmedPrompt = _promptController.text.trim();

    if (_originalImageBytes == null) {
      setState(() => _errorMessage = 'Lütfen önce bir resim seçin.');
      return;
    }
    if (trimmedPrompt.isEmpty) {
      setState(() => _errorMessage = 'Lütfen bir prompt (talimat) girin.');
      return;
    }

    setState(() {
      _prompt = trimmedPrompt;
      _isLoading = true;
      _errorMessage = '';
      _editedImageBytes = null;
      _downloadImageUrl = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.fields['prompt'] = _prompt;
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          _originalImageBytes!,
          filename: 'image.png',
        ),
      );

      var streamedResponse = await request.send();
      var responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception('API Hatası: ${streamedResponse.statusCode} - ${json.decode(responseBody)['error'] ?? 'Bilinmeyen Hata'}');
      }

      var data = json.decode(responseBody);

      if (data['status'] == 'success' && data['result']['images'] != null && data['result']['images'].isNotEmpty) {
        var imageUrl = data['result']['images'][0]['url'];

        var imageBytes = await http.readBytes(Uri.parse(imageUrl));
        setState(() {
          _editedImageBytes = imageBytes;
          _downloadImageUrl = imageUrl;

          // Geçmişe kaydet (yeni fotoğraf seçilse bile korunuyor)
          if (_originalImageBase64 != null) {
            _imageHistory.insert(0, ImageHistoryItem(
              originalImageUrl: _originalImageBase64!,
              prompt: trimmedPrompt,
              resultImageUrl: imageUrl,
              timestamp: DateTime.now(),
            ));
          }
        });
      } else {
        throw Exception('Görsel oluşturma başarısız. Yanıt formatı beklenmiyor veya resim bulunamadı.');
      }

    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        _errorMessage = 'Görsel oluşturulurken bir hata oluştu: ${e.toString().split('Exception: ').last}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Resim veya boş durum için kullanılan ana görsel konteyner widget'ı
  Widget _buildImageContainer(Uint8List? imageBytes, String placeholderText, Color borderColor, {bool isResult = false}) {
    return Card(
      elevation: isResult ? 6 : 2, // Sonuç için daha belirgin gölge
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isResult ? 3.0 : 1.5),
      ),
      child: Container(
        height: 250,
        alignment: Alignment.center, // Resmi ortaya almak için
        decoration: BoxDecoration(
          color: Colors.grey[50], // Hafif renk
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack( // İndirme butonu için Stack kullanıldı
          children: [
            // Resmin boyutu küçültülüp ortalanır
            imageBytes != null
                ? SizedBox( // Çerçeveyi küçültmek ve sığdırmak için
              width: 200,
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain, // Resmi konteynere sığdır
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text("Görsel yüklenemedi", style: TextStyle(color: errorColor)));
                  },
                ),
              ),
            )
                : Center(
              child: Text(
                placeholderText,
                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),

            // Yeni: İndirme Butonu (Sadece sonuç görseli varsa ve sonuç ekranıysa görünür)
            if (isResult && imageBytes != null)
              Positioned(
                top: 10,
                right: 10,
                child: MouseRegion( // Hover efekti için MouseRegion eklendi (Web/Masaüstü)
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: downloadImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5), // Yarı saydam siyah arka plan
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.file_download,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Voltran AI Image Editor',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: primaryColor, // Koyu Mavi App Bar
        elevation: 10,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resim Seçme Butonu
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload, size: 24),
              onPressed: pickImage,
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('Giriş Resmini Seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
            ),
            const SizedBox(height: 20),

            // Orijinal Resim Önizlemesi Başlığı
            Text(
              'Orijinal Resim',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 10),

            // Orijinal Resim Önizlemesi
            _buildImageContainer(
                _originalImageBytes,
                'Resim seçmek için yukarıdaki butona tıklayın.',
                primaryColor
            ),
            const SizedBox(height: 30),

            // Prompt Girişi
            Text(
              'Dönüşüm Talimatı (Prompt)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _promptController,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 4, // Birden fazla satır girebilmek için
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 2.5),
                ),
                labelText: 'Resmi nasıl değiştirmek istediğinizi yazın',
                hintText: 'Örn: "Arka planı siyah yap, karakteri fütüristik bir zırhla donat."',
                prefixIcon: const Icon(Icons.brush, color: primaryColor),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.blue.shade50,
              ),
              onChanged: (value) => {}, // Controller kullandığımız için burası boş kalabilir
            ),
            const SizedBox(height: 30),

            // Hata Mesajı
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20.0),
                decoration: BoxDecoration(
                  color: errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: errorColor, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: errorColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hata: $_errorMessage',
                        style: const TextStyle(color: errorColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Generate Butonu
            ElevatedButton(
              onPressed: _isLoading ? null : generateImage,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : const Text('Görseli Dönüştür', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
                disabledBackgroundColor: accentColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 30),

            // Dönüştürülmüş Resim Başlığı
            Text(
              'Son Dönüştürülmüş Resim',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Dönüştürülmüş Resim (Standart Önizleme)
            Stack(
              alignment: Alignment.center,
              children: [
                _buildImageContainer(
                    _editedImageBytes,
                    _isLoading ? 'Dönüştürülüyor...' : 'Dönüştürülen resim sonucu burada görünecek',
                    accentColor,
                    isResult: true
                ),
                // Büyük, ortalanmış yükleniyor göstergesi
                if (_isLoading && _editedImageBytes == null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(15)
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 30),

            // --- Düzenleme Geçmişi ---
            if (_imageHistory.isNotEmpty) ...[
              Text(
                'Düzenleme Geçmişi (${_imageHistory.length})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _imageHistory.length,
                itemBuilder: (context, index) {
                  final item = _imageHistory[index];

                  // Görselin Base64 verisini Bytes'a çevirme
                  final historyImageBytes = base64Decode(item.originalImageUrl);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      // Sol: Orijinal Görsel
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // Geçmişteki öğenin orijinal görselini gösteriyoruz
                          child: Image.memory(historyImageBytes, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported)),
                          ),
                        ),
                      ),
                      // Orta: Prompt
                      title: Text(item.prompt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      // Alt: Tarih
                      subtitle: Text('Tarih: ${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year} ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey[600])),
                      // Sağ: İndirme Butonu
                      trailing: IconButton(
                        icon: const Icon(Icons.download, color: primaryColor),
                        onPressed: () {
                          // Geçmişteki görseli indirmek için
                          _downloadSpecificImage(item.resultImageUrl);
                        },
                      ),
                      // Tıklama: Sonuç görselini ana ekrana yükleme
                      onTap: () {
                        _loadHistoryItem(item);
                      },
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Geçmişteki bir görseli ana ekrana yükleme
  void _loadHistoryItem(ImageHistoryItem item) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Sonucu önizlemeye yükle
      var resultImageBytes = await http.readBytes(Uri.parse(item.resultImageUrl));
      // Orijinali önizlemeye yükle (Base64'den)
      var originalImageBytes = base64Decode(item.originalImageUrl);

      setState(() {
        _originalImageBytes = originalImageBytes;
        _editedImageBytes = resultImageBytes;
        _downloadImageUrl = item.resultImageUrl;
        _promptController.text = item.prompt;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçmişteki görsel önizlemeye yüklendi.')),
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Geçmiş görsel yüklenemedi: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Geçmişteki bir görseli indirme (downloadImage'ın aynısı ama URL'yi doğrudan alıyor)
  void _downloadSpecificImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final blob = response.bodyBytes;

        final htmlUrl = html.Url.createObjectUrlFromBlob(html.Blob([blob]));
        final anchor = html.AnchorElement(href: htmlUrl)
          ..setAttribute("download", "ai_history_edit_${DateTime.now().millisecondsSinceEpoch}.png")
          ..click();
        html.Url.revokeObjectUrl(htmlUrl);

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geçmiş görseli indirilmeye başlandı.')),
          );
        }

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel indirilemedi: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İndirme sırasında hata oluştu: ${e.toString()}')),
      );
    }
  }
}

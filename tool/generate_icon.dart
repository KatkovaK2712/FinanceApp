import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final inputPath = 'assets/images/maneki-neko.png';
  final outputPath = 'assets/images/icon_final.png';
  
  final imageBytes = await File(inputPath).readAsBytes();
  img.Image? original = img.decodeImage(imageBytes);
  
  if (original == null) {
    print('❌ Не удалось загрузить изображение');
    return;
  }
  
  print('✅ Загружено: ${original.width}x${original.height}');
  
  // Конечный размер иконки
  final targetSize = 512;
  
  // Уменьшаем, чтобы кошка поместилась с отступами (80% от размера)
  final imageSize = (targetSize * 0.5).toInt();
  final resized = img.copyResize(original, width: imageSize, height: imageSize);
  
  // Создаём пустое изображение с отступами
  final outputImage = img.Image(width: targetSize, height: targetSize);
  
  // Вычисляем отступы, чтобы кошка была по центру
  final offsetX = (targetSize - imageSize) ~/ 2;
  final offsetY = (targetSize - imageSize) ~/ 2;
  
  // Цвета градиента
  final colors = [
    [65, 88, 208],   // синий
    [200, 80, 192],  // розовый
    [255, 204, 112], // жёлтый
  ];
  
  for (int y = 0; y < imageSize; y++) {
    for (int x = 0; x < imageSize; x++) {
      final pixel = resized.getPixel(x, y);
      
      if (pixel.a > 50) {
        final progress = (offsetX + x) / targetSize;
        
        int red, green, blue;
        
        if (progress < 0.5) {
          final t = progress / 0.5;
          red = (colors[0][0] * (1 - t) + colors[1][0] * t).toInt();
          green = (colors[0][1] * (1 - t) + colors[1][1] * t).toInt();
          blue = (colors[0][2] * (1 - t) + colors[1][2] * t).toInt();
        } else {
          final t = (progress - 0.5) / 0.5;
          red = (colors[1][0] * (1 - t) + colors[2][0] * t).toInt();
          green = (colors[1][1] * (1 - t) + colors[2][1] * t).toInt();
          blue = (colors[1][2] * (1 - t) + colors[2][2] * t).toInt();
        }
        
        outputImage.setPixelRgba(offsetX + x, offsetY + y, red, green, blue, 255);
      }
    }
  }
  
  final outputBytes = img.encodePng(outputImage);
  await File(outputPath).writeAsBytes(outputBytes);
  
  print('✅ Иконка создана: $outputPath (${targetSize}x${targetSize})');
}
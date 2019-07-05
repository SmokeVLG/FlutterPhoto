import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as DartImage;
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

//Список доступных камер на устройстве
List<CameraDescription> cameras;
final LINE_BREAK_CODE = 10;

Future<void> main() async {
  // Получить список доступных камер на устройстве.
  cameras = await availableCameras();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final firstCamera = cameras.first;

  @override
  Widget build(BuildContext context) {
    // Container usage: interval, bgcolor, filleted corner, frame, align, bgpic
    return MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen Widget
        camera: firstCamera,
      ),
    );
  }
}

// Экран, который принимает список камер и каталог для хранения изображений.
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

//Future<void> - либо пустоту вернет либо ошибку
class TakePictureScreenState extends State<TakePictureScreen> {
  //Add a variable to the State class to store the CameraController.
  //Add a variable to the State class to store the Future returned from CameraController.initialize().
  CameraController _controller;
  Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // Для отображения выхода из камеры необходимо создать
    // CameraController.
    _controller = CameraController(
      // Получить конкретную камеру из списка доступных камер.
      widget.camera,
      //Определите разрешение для использования.
      ResolutionPreset.medium,
    );

    // Далее необходимо инициализировать контроллер. Он возвращает Future
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Утилизируйте контроллер при удалении виджета.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Сделайте фото')),
      // Вы должны дождаться инициализации контроллера, прежде чем отобразить
      // предварительный просмотр камеры. Используйте FutureBuilder для отображения загрузочного счетчика, пока
      // контроллер завершил инициализацию.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Если будущее завершено, отобразите предварительный просмотр.
            return CameraPreview(_controller);
          } else {
            // В противном случае отобразите индикатор загрузки.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        // Нажатие на кнопку
        onPressed: () async {
          // Сделайте снимок в блоке try / catch. Если что-то пойдет не так,
          // ловим ошибку.
          try {
            // Убедитесь, что камера инициализируется
            await _initializeControllerFuture;

            // Путь, по которому изображение должно быть сохранено
            final pathJpeg = join(
              // В этом примере  изображение сохраняется во временном каталоге.
              (await getTemporaryDirectory()).path,
              '${DateTime.now()}.jpg',
            );

            // Attempt to take a picture and log where it's been saved
            await _controller.takePicture(pathJpeg);

            // Create an image
            _takePicture(pathJpeg);

            // Если снимок был сделан, отобразите его на новом экране
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(imagePath: pathJpeg),
              ),
            );
          } catch (e) {
            // При возникновении ошибки внесите ее в журнал консоли.
            print(e);
          }
        },
      ),
    );
  }

  Future _takePicture(String pathJpeg) async {
    // Create an image
    debugPrint("decodeImage");
    DartImage.Image image =
    DartImage.decodeImage(File(pathJpeg).readAsBytesSync());
    debugPrint("resizeImage");
    DartImage.Image newImage;
    //2mp = 1920(Width ) на 1080 (height)
    if (!image.exif.hasOrientation || image.exif.orientation > 4) {
      newImage = DartImage.copyResize(image, height: 1920);
    } else {
      newImage = DartImage.copyResize(image, width: 1920);
    }

    debugPrint("drawString");
    //Цвет задается в RGB формате
    int rectangleColor = DartImage.getColor(255, 0, 0);
    int textColor = DartImage.getColor(0, 0, 0);

    ByteData data =
    await rootBundle.load("assets/fonts/RobotoCondensed_Regular_20.zip");
    List<int> bytes =
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    var bitmapFont = DartImage.BitmapFont.fromZip(bytes);

    var printText =
        '01.07.2019 13:46:37 \n Филоничев Александр Анатольевич ИП, 450030 Респ,, Уфа г.Боровая ел 14,13,; Доля полки (ЦО) \n'
        'Кондиционеры для белья111111113434343434343434343\n\n\n4ergwergwergwergwergwergwegrwergewrgergewrg343434343434343434343434343434343434343434343434343411111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111';
    int heightStr = getHeightStr(newImage, bitmapFont, 10, 10, printText);

    for (int i = 0; i < heightStr; i++) {
      DartImage.drawLine(newImage, 0, i, newImage.width, i, rectangleColor);
    }

    drawString(newImage, bitmapFont, 10, 10, printText, color: textColor);

    var encodeJpg = DartImage.encodeJpg(newImage, quality: 80);
    debugPrint("writeAsBytesSync");
    File(pathJpeg).writeAsBytesSync(encodeJpg);
  }

  DartImage.Image drawString(DartImage.Image image, DartImage.BitmapFont font,
      int x, int y, String string,
      {int color = 0xffffffff}) {
    int startX = x;

    var _r_lut = Uint8List(256);
    var _g_lut = Uint8List(256);
    var _b_lut = Uint8List(256);
    var _a_lut = Uint8List(256);

    if (color != 0xffffffff) {
      int ca = DartImage.getAlpha(color);
      if (ca == 0) {
        return image;
      }
      num da = ca / 255.0;
      num dr = DartImage.getRed(color) / 255.0;
      num dg = DartImage.getGreen(color) / 255.0;
      num db = DartImage.getBlue(color) / 255.0;
      for (int i = 1; i < 256; ++i) {
        _r_lut[i] = (dr * i).toInt();
        _g_lut[i] = (dg * i).toInt();
        _b_lut[i] = (db * i).toInt();
        _a_lut[i] = (da * i).toInt();
      }
    }

    List<int> chars = string.codeUnits;
    for (int c in chars) {
      if (!font.characters.containsKey(c) && c != LINE_BREAK_CODE) {
        x += font.base ~/ 2;
        continue;
      }
      //Ищем текущий символов в массиве шрифтов
      DartImage.BitmapFontCharacter ch = font.characters[c];

      int x2 = 0;
      int y2 = 0;
      //Здесь должна быть проверка
      //Если конец строки, то обннуляем значени по горизонтали и увеличиваеим по вертикали
      //Пусть отступ от верхней строки будет 10 пикселей
      if (LINE_BREAK_CODE == c || x + ch.width + ch.xadvance >= image.width) {
        x = startX;
        //Делаем отступ размером в символ.
        y = y + font.lineHeight;
        if (c == LINE_BREAK_CODE) continue;
      }

      x2 = x + ch.width;
      y2 = y + ch.height;
      int pi = 0;
      for (int yi = y; yi < y2; ++yi) {
        for (int xi = x; xi < x2; ++xi) {
          int p = ch.image[pi++];
          if (color != 0xffffffff) {
            p = DartImage.getColor(
                _r_lut[DartImage.getRed(p)],
                _g_lut[DartImage.getGreen(p)],
                _b_lut[DartImage.getBlue(p)],
                _a_lut[DartImage.getAlpha(p)]);
          }
          DartImage.drawPixel(image, xi + ch.xoffset, yi + ch.yoffset, p);
        }
      }
      x += ch.xadvance;
    }
    return image;
  }

  int getHeightStr(DartImage.Image image, DartImage.BitmapFont font, int x,
      int y, String string) {
    int startX = x;
    List<int> chars = string.codeUnits;
    for (int c in chars) {
      if (!font.characters.containsKey(c) && c != LINE_BREAK_CODE) {
        x += font.base ~/ 2;
        continue;
      }
      DartImage.BitmapFontCharacter ch = font.characters[c];

      if (LINE_BREAK_CODE == c || x + ch.width + ch.xadvance >= image.width) {
        x = startX;
        y = y + font.lineHeight;
        if (c == LINE_BREAK_CODE) continue;
      }
      x += ch.xadvance;
    }
    return y + font.lineHeight;
  }
}

// Виджет для отображения картинки, сделанной пользователем
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key key, this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Просмотр фото')),
      //Фото сохраняется в памяти на девайсе. Используйте `Image.file`
      // На вход конструктора подается путь к файлу.
      body: Image.file(File(imagePath)),
    );
  }
}

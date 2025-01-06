import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui; // Для Offset, Path
import 'package:flutter/material.dart';

/// Тип страны (упрощённо)
enum CountryType {
  player, // Игрок (синий)
  ai      // Остальные государства
}

/// Класс, описывающий страну
class Country {
  final String name;
  CountryType type;

  /// Сила (для упрощения симуляции войны/мира)
  int strength;

  /// Цвет территории
  Color color;

  /// Многоугольник (Path), описывающий границы
  Path boundary;

  /// Имена стран, с которыми идёт война
  Set<String> atWarWith;

  /// Имена стран, с которыми союз
  Set<String> allies;

  Country({
    required this.name,
    required this.type,
    required this.strength,
    required this.color,
    required this.boundary,
    required this.atWarWith,
    required this.allies,
  });
}

void main() {
  runApp(const MyApp());
}

/// Корневой виджет приложения
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strategy Demo with Splash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(), // <-- Сначала показываем сплэш
    );
  }
}

/// Сплэш-экран со скромной анимацией
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация «плавного появления» (от 0 к 1) за 2 секунды
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward(); // Запускаем анимацию

    // Через 3 секунды переходим на GameScreen
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.blueAccent,
          child: const Center(
            child: Text(
              'My Strategy Game',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Основной экран игры
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random random = Random();
  final List<Country> countries = [];

  Offset mapOffset = Offset.zero; // смещение карты
  double scale = 1.0;             // масштаб

  Country? selectedCountry;       // выбранная страна при тапе

  @override
  void initState() {
    super.initState();
    scale = 0.3; // чтобы «видеть» всё с начала
    _generateCountries();
    _startAiWarsSimulation();
  }

  /// Генерация стран (1 игрок, 6 AI) со случайной силой,
  /// но с уникальным цветом для каждой.
  void _generateCountries() {
    int total = 7; // 1 страна — игрок, 6 стран — AI
    for (int i = 0; i < total; i++) {
      bool isPlayer = (i == 0);

      // Генерируем многоугольник в диапазоне (±300)
      Path path = _randomPolygon(
        center: Offset(
          random.nextDouble() * 600 - 300,
          random.nextDouble() * 600 - 300,
        ),
        radius: 100 + random.nextDouble() * 100,
        sides: 5 + random.nextInt(4),
      );

      // Если это игрок — цвет синий, иначе берём уникальный оттенок
      Color countryColor;
      if (isPlayer) {
        countryColor = Colors.blue;
      } else {
        countryColor = _distinctColor(i, total);
      }

      countries.add(
        Country(
          name: isPlayer ? "My Kingdom" : "AI State #$i",
          type: isPlayer ? CountryType.player : CountryType.ai,
          strength: random.nextInt(100) + 50, // 50..149
          color: countryColor,
          boundary: path,
          atWarWith: {},
          allies: {},
        ),
      );
    }
  }

  /// Возвращает «уникальный» цвет для i-й страны (кроме игрока),
  /// равномерно распределяя оттенок (hue) на цветовом круге.
  Color _distinctColor(int index, int total) {
    // Если index=0 — это игрок, но мы используем этот метод
    // только для стран-ботов (index>0).
    // hue = (360 / total) * index
    // saturation=0.6, lightness=0.4, можно менять по вкусу.
    double hue = (index * (360 / total)) % 360;
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.6, 0.4);
    return hsl.toColor();
  }

  /// Генерация случайного многоугольника
  Path _randomPolygon({
    required Offset center,
    required double radius,
    required int sides,
  }) {
    final path = Path();
    double angleStep = 2 * pi / sides;
    for (int i = 0; i < sides; i++) {
      double r = radius * (0.5 + random.nextDouble() * 0.5);
      double angle = i * angleStep + random.nextDouble() * (angleStep / 3);
      double x = center.dx + r * cos(angle);
      double y = center.dy + r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Пинч-зум
  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      scale = (scale * details.scale).clamp(0.2, 5.0);
      mapOffset += details.focalPointDelta / scale;
    });
  }

  /// Тап: проверяем, попали ли в какую-нибудь страну
  void _onTapDown(TapDownDetails details) {
    final localPos = (details.localPosition - mapOffset) / scale;

    for (final c in countries.reversed) {
      if (c.boundary.contains(localPos)) {
        setState(() {
          selectedCountry = c;
        });
        _showCountryDialog(c);
        return;
      }
    }

    setState(() {
      selectedCountry = null;
    });
  }

  /// Диалог с дипломатией (война, мир, союз и т.д.)
  void _showCountryDialog(Country target) {
    if (target == myKingdom) return; // если клик по себе

    bool isAtWar = _isAtWar(myKingdom, target);
    bool isAllied = _isAllied(myKingdom, target);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("${target.name} (Str: ${target.strength})"),
          content: Text("You have selected ${target.name}."),
          actions: [
            // 1) Declare War / Make Peace
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (!isAtWar) {
                  _declareWar(myKingdom, target);
                } else {
                  _makePeace(myKingdom, target);
                }
              },
              child: Text(isAtWar ? "Make Peace" : "Declare War"),
            ),

            // 2) Alliance
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (!isAllied) {
                  _formAlliance(myKingdom, target);
                } else {
                  _breakAlliance(myKingdom, target);
                }
              },
              child: Text(isAllied ? "Break Alliance" : "Form Alliance"),
            ),

            // 3) Invade / Invade with Allies (если воюем)
            if (isAtWar) ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _invade(myKingdom, target);
                },
                child: const Text("Invade Alone"),
              ),
              if (myKingdom.allies.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _invadeWithAllies(myKingdom, target);
                  },
                  child: const Text("Invade with Allies"),
                ),
            ],

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  /// Находим «нашу» страну
  Country get myKingdom =>
      countries.firstWhere((c) => c.type == CountryType.player);

  bool _isAtWar(Country a, Country b) {
    return a.atWarWith.contains(b.name) && b.atWarWith.contains(a.name);
  }

  bool _isAllied(Country a, Country b) {
    return a.allies.contains(b.name) && b.allies.contains(a.name);
  }

  // -- Методы дипломатии --

  void _declareWar(Country a, Country b) {
    setState(() {
      a.atWarWith.add(b.name);
      b.atWarWith.add(a.name);
      // разрываем союз, если был
      a.allies.remove(b.name);
      b.allies.remove(a.name);
    });
  }

  void _makePeace(Country a, Country b) {
    setState(() {
      a.atWarWith.remove(b.name);
      b.atWarWith.remove(a.name);
    });
  }

  void _formAlliance(Country a, Country b) {
    setState(() {
      // прекращаем войну, если была
      a.atWarWith.remove(b.name);
      b.atWarWith.remove(a.name);
      // союз
      a.allies.add(b.name);
      b.allies.add(a.name);
    });
  }

  void _breakAlliance(Country a, Country b) {
    setState(() {
      a.allies.remove(b.name);
      b.allies.remove(a.name);
    });
  }

  void _invade(Country a, Country b) {
    setState(() {
      b.type = a.type;
      b.color = a.color;
      // убираем войны
      b.atWarWith.clear();
      a.atWarWith.remove(b.name);
      // стираем союзы b
      b.allies.clear();
    });
  }

  void _invadeWithAllies(Country a, Country b) {
    setState(() {
      b.type = a.type;
      b.color = a.color;
      b.atWarWith.clear();
      a.atWarWith.remove(b.name);
      b.allies.clear();
    });
  }

  // -- AI Симуляция --

  void _startAiWarsSimulation() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        final aiCountries = countries.where((c) => c.type == CountryType.ai).toList();
        if (aiCountries.length < 2) return;

        final c1 = aiCountries[random.nextInt(aiCountries.length)];
        final c2 = aiCountries[random.nextInt(aiCountries.length)];
        if (c1 == c2) return;

        bool isAtWar = _isAtWar(c1, c2);
        bool isAllied = _isAllied(c1, c2);

        // 50% шанс что-то поменять
        if (random.nextBool()) {
          if (!isAtWar && !isAllied) {
            // либо война, либо союз
            if (random.nextBool()) {
              _declareWar(c1, c2);
            } else {
              _formAlliance(c1, c2);
            }
          } else {
            // если воюют — мир, если союз — разрыв
            if (isAtWar) {
              _makePeace(c1, c2);
            } else if (isAllied) {
              _breakAlliance(c1, c2);
            }
          }
        }

        // Авто-мир для проигрывающих
        for (final cA in aiCountries) {
          for (final cB in aiCountries) {
            if (cA == cB) continue;
            if (_isAtWar(cA, cB)) {
              if (cA.strength * 2 < cB.strength) {
                _makePeace(cA, cB);
              }
            }
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategic Demo Game'),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Zoom in
          FloatingActionButton(
            heroTag: "zoom_in",
            onPressed: () {
              setState(() {
                scale = (scale + 0.1).clamp(0.2, 5.0);
              });
            },
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 10),
          // Zoom out
          FloatingActionButton(
            heroTag: "zoom_out",
            onPressed: () {
              setState(() {
                scale = (scale - 0.1).clamp(0.2, 5.0);
              });
            },
            child: const Icon(Icons.zoom_out),
          ),
        ],
      ),
      body: GestureDetector(
        onTapDown: _onTapDown,
        onScaleUpdate: _onScaleUpdate,
        child: Transform.translate(
          offset: mapOffset,
          child: Transform.scale(
            scale: scale,
            child: Stack(
              children: [
                // «Бесконечный» белый фон
                Positioned(
                  left: -20000,
                  top: -20000,
                  child: Container(
                    width: 40000,
                    height: 40000,
                    color: Colors.white,
                  ),
                ),

                // Отрисовка стран (многоугольников)
                Positioned(
                  left: -20000,
                  top: -20000,
                  child: CustomPaint(
                    size: const Size(40000, 40000),
                    painter: CountriesPainter(countries),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter, который рисует страны (заливка + обводка, если воюют/союзничают)
class CountriesPainter extends CustomPainter {
  final List<Country> countries;
  CountriesPainter(this.countries);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in countries) {
      // Заливка цветом
      final fillPaint = Paint()
        ..color = c.color
        ..style = PaintingStyle.fill;
      canvas.drawPath(c.boundary, fillPaint);

      // Обводим красным, если воюет
      if (c.atWarWith.isNotEmpty) {
        final borderPaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        canvas.drawPath(c.boundary, borderPaint);
      }

      // Обводим зелёным, если есть союзники
      if (c.allies.isNotEmpty) {
        final borderPaint = Paint()
          ..color = Colors.green
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        canvas.drawPath(c.boundary, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CountriesPainter oldDelegate) => true;
}

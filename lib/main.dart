import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui; 
import 'package:flutter/material.dart';

/// Тип страны
enum CountryType {
  player, // Игрок (синий)
  ai      // Остальные государства
}

/// Класс, описывающий страну
class Country {
  final String name;
  CountryType type;

  /// Сила (кол-во солдат), влияет на исход сражений
  int strength;

  /// Цвет
  Color color;

  /// Выпуклая оболочка (Path), описывающая границы
  Path boundary;

  /// Воюем с...
  Set<String> atWarWith;

  /// Союзники
  Set<String> allies;

  /// Резерв (для вербовки)
  int reserve;

  /// Точка "сид" для вороньей диаграммы
  final Offset seed;

  /// Соседи (страны, с которыми физически граничит)
  Set<String> neighbors;

  Country({
    required this.name,
    required this.type,
    required this.strength,
    required this.color,
    required this.boundary,
    required this.atWarWith,
    required this.allies,
    required this.reserve,
    required this.seed,
    required this.neighbors,
  });
}

void main() {
  runApp(const MyApp());
}

/// Корневой виджет
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
      home: const SplashScreen(),
    );
  }
}

/// Сплэш-экран
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    // Через 3 секунды — переход
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

/// Основной экран
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random random = Random();
  final List<Country> countries = [];

  Offset mapOffset = Offset.zero;
  double scale = 1.0;

  Country? selectedCountry;

  @override
  void initState() {
    super.initState();
    _generateVoronoiCountries();
    _startAiWarsSimulation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFit();
    });
  }

  /// Генерация стран c вороньей диаграммой
  void _generateVoronoiCountries() {
    const int total = 7; 
    for (int i = 0; i < total; i++) {
      bool isPlayer = (i == 0);
      final seedPoint = Offset(
        random.nextDouble() * 600 - 300,
        random.nextDouble() * 600 - 300,
      );
      Color c = isPlayer ? Colors.blue : _distinctColor(i, total);

      countries.add(
        Country(
          name: isPlayer ? "My Kingdom" : "AI State #$i",
          type: isPlayer ? CountryType.player : CountryType.ai,
          strength: random.nextInt(80) + 20,
          color: c,
          boundary: Path(),
          atWarWith: {},
          allies: {},
          reserve: random.nextInt(100) + 50,
          seed: seedPoint,
          neighbors: {},
        ),
      );
    }

    // Создаём «принадлежность» пикселей
    final ownership = <Country, List<Offset>>{};
    for (final c in countries) {
      ownership[c] = [];
    }

    final double minCoord = -300, maxCoord = 300;
    const int steps = 150; 

    final dx = (maxCoord - minCoord) / steps;
    final dy = (maxCoord - minCoord) / steps;

    // Для соседства: если меняется страна между (x,y) и (x+1,y), значит граничащие
    // Аналогично (x,y+1).
    Country? lastCountryX;
    Country? lastCountryY;

    // Храним пары (A,B), которые граничат
    final Set<(String, String)> adjacency = {};

    for (int ix = 0; ix <= steps; ix++) {
      for (int iy = 0; iy <= steps; iy++) {
        final x = minCoord + ix * dx;
        final y = minCoord + iy * dy;

        // 1) Находим ближайший сид
        Country? bestC;
        double bestDist = double.infinity;
        for (final c in countries) {
          final dist = (Offset(x, y) - c.seed).distanceSquared;
          if (dist < bestDist) {
            bestDist = dist;
            bestC = c;
          }
        }
        ownership[bestC]!.add(Offset(x, y));

        // 2) Проверяем «слева» и «сверху»:
        // left => (ix-1, iy) 
        // up => (ix, iy-1)
        // но для этого нужно вспомнить, кто там был
        // (чтобы узнать, не другой ли это country)
        // 
        // a) Слева
        if (ix > 0) {
          // Возьмём предыдущий ix-1, тот же iy
          final xLeft = minCoord + (ix - 1) * dx;
          final ySame = y;
          final cLeft = _findNearestCountry(Offset(xLeft, ySame));
          if (cLeft != null && cLeft != bestC) {
            adjacency.add((cLeft.name, bestC!.name));
            adjacency.add((bestC.name, cLeft.name));
          }
        }
        // б) Сверху
        if (iy > 0) {
          final xSame = x;
          final yUp = minCoord + (iy - 1) * dy;
          final cUp = _findNearestCountry(Offset(xSame, yUp));
          if (cUp != null && cUp != bestC) {
            adjacency.add((cUp.name, bestC!.name));
            adjacency.add((bestC.name, cUp.name));
          }
        }
      }
    }

    // Собрали все точки для каждой country.  
    // Теперь делаем оболочку.
    for (final c in countries) {
      final pts = ownership[c]!;
      if (pts.isEmpty) {
        c.boundary = Path();
      } else {
        final hull = _computeConvexHull(pts);
        c.boundary = Path()..addPolygon(hull, true);
      }
    }

    // Заполняем neighbors
    for (final pair in adjacency) {
      // pair = (A, B)
      final cA = countries.firstWhere((x) => x.name == pair.$1);
      final cB = countries.firstWhere((x) => x.name == pair.$2);
      cA.neighbors.add(cB.name);
      cB.neighbors.add(cA.name);
    }
  }

  /// Находим страну по ближайшему сид
  Country? _findNearestCountry(Offset pos) {
    Country? best;
    double distBest = double.infinity;
    for (final c in countries) {
      final d = (pos - c.seed).distanceSquared;
      if (d < distBest) {
        distBest = d;
        best = c;
      }
    }
    return best;
  }

  /// Простейший «gift wrapping» для оболочки
  List<Offset> _computeConvexHull(List<Offset> pts) {
    if (pts.length < 3) return pts;

    Offset start = pts[0];
    for (final p in pts) {
      if (p.dx < start.dx) {
        start = p;
      } else if (p.dx == start.dx && p.dy < start.dy) {
        start = p;
      }
    }
    final hull = <Offset>[];
    Offset current = start;
    Offset? next;

    do {
      hull.add(current);
      next = pts[0];
      for (int i = 1; i < pts.length; i++) {
        final cross = _cross(next! - current, pts[i] - current);
        if (cross > 0 ||
            (cross == 0 &&
                (pts[i] - current).distanceSquared >
                    (next - current).distanceSquared)) {
          next = pts[i];
        }
      }
      // current = next;
    } while (current != start);

    return hull;
  }

  double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

  Color _distinctColor(int index, int total) {
    double hue = (index * (360 / total)) % 360;
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.6, 0.4);
    return hsl.toColor();
  }

  /// Авто-фокус
  void _autoFit() {
    if (countries.isEmpty) return;
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (final c in countries) {
      final r = c.boundary.getBounds();
      if (r.left < minX) minX = r.left;
      if (r.right > maxX) maxX = r.right;
      if (r.top < minY) minY = r.top;
      if (r.bottom > maxY) maxY = r.bottom;
    }

    final w = maxX - minX;
    final h = maxY - minY;
    final screenSize = MediaQuery.of(context).size;

    double desiredScale = 0.8 * min(
      screenSize.width / (w == 0 ? 1 : w),
      screenSize.height / (h == 0 ? 1 : h),
    );
    desiredScale = desiredScale.clamp(0.05, 10.0);

    setState(() {
      scale = desiredScale;
      final cx = (minX + maxX) / 2;
      final cy = (minY + maxY) / 2;
      final scrCenter = Offset(screenSize.width / 2, screenSize.height / 2);
      mapOffset = scrCenter - Offset(cx, cy) * scale;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      final newS = scale * d.scale;
      scale = newS.clamp(0.05, 10.0);
      mapOffset += d.focalPointDelta / scale;
    });
  }

  void _onTapDown(TapDownDetails d) {
    final localPos = (d.localPosition - mapOffset) / scale;
    for (final c in countries.reversed) {
      if (c.boundary.contains(localPos)) {
        setState(() => selectedCountry = c);
        _showCountryDialog(c);
        return;
      }
    }
    setState(() => selectedCountry = null);
  }

  /// Показываем диалог
  void _showCountryDialog(Country target) {
    bool isPlayer = (target == myKingdom);
    bool isAtWar = _isAtWar(myKingdom, target);
    bool isAllied = _isAllied(myKingdom, target);

    showDialog(
      context: context,
      builder: (_) {
        // Показать ещё и «neighbors»
        final neighborsStr = target.neighbors.join(", ");

        return AlertDialog(
          title: Text(
            "${target.name} (Str: ${target.strength}), "
            "Neighbors: [$neighborsStr]",
          ),
          content: Text("You have selected ${target.name}."),
          actions: [
            if (isPlayer)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _recruitTroops(myKingdom);
                },
                child: const Text("Recruit (+10)"),
              ),

            if (!isPlayer) ...[
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
              if (isAtWar)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _invadeWithBattle(myKingdom, target);
                  },
                  child: const Text("Invade"),
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

  // --- Логика ---
  Country get myKingdom =>
      countries.firstWhere((c) => c.type == CountryType.player);

  bool _isAtWar(Country a, Country b) =>
      a.atWarWith.contains(b.name) && b.atWarWith.contains(a.name);

  bool _isAllied(Country a, Country b) =>
      a.allies.contains(b.name) && b.allies.contains(a.name);

  void _recruitTroops(Country c) {
    setState(() {
      if (c.reserve >= 10) {
        c.reserve -= 10;
        c.strength += 10;
      } else if (c.reserve > 0) {
        int can = c.reserve;
        c.reserve = 0;
        c.strength += can;
      }
    });
  }

  void _declareWar(Country a, Country b) {
    setState(() {
      a.atWarWith.add(b.name);
      b.atWarWith.add(a.name);
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
      a.atWarWith.remove(b.name);
      b.atWarWith.remove(a.name);
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

  void _invadeWithBattle(Country a, Country b) {
    if (a.strength > b.strength) {
      setState(() {
        b.type = a.type;
        b.color = a.color;
        b.atWarWith.clear();
        a.atWarWith.remove(b.name);
        b.allies.clear();
      });
    } else {
      setState(() {
        int loss = 5 + random.nextInt(11);
        a.strength = max(0, a.strength - loss);
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Attack failed!"),
          content: Text(
            "${a.name} attacked ${b.name} but was repelled.\n"
            "Your army lost some soldiers!",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _startAiWarsSimulation() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        final ai = countries.where((x) => x.type == CountryType.ai).toList();
        if (ai.length < 2) return;

        final c1 = ai[random.nextInt(ai.length)];
        final c2 = ai[random.nextInt(ai.length)];
        if (c1 == c2) return;

        bool isAtWar = _isAtWar(c1, c2);
        bool isAllied = _isAllied(c1, c2);

        if (random.nextBool()) {
          if (!isAtWar && !isAllied) {
            if (random.nextBool()) {
              _declareWar(c1, c2);
            } else {
              _formAlliance(c1, c2);
            }
          } else {
            if (isAtWar) {
              _makePeace(c1, c2);
            } else if (isAllied) {
              _breakAlliance(c1, c2);
            }
          }
        }

        // Слабые пытаются мир
        for (final cA in ai) {
          for (final cB in ai) {
            if (cA == cB) continue;
            if (_isAtWar(cA, cB)) {
              if (cA.strength * 2 < cB.strength) {
                _makePeace(cA, cB);
              }
            }
          }
        }

        // Вербовка AI
        if (random.nextBool()) {
          if (c1.reserve > 0) {
            int recruit = min(c1.reserve, 5 + random.nextInt(6));
            c1.reserve -= recruit;
            c1.strength += recruit;
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
                final newS = scale + 0.1;
                scale = newS.clamp(0.05, 10.0);
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
                final newS = scale - 0.1;
                scale = newS.clamp(0.05, 10.0);
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
                Positioned(
                  left: -20000,
                  top: -20000,
                  child: Container(
                    width: 40000,
                    height: 40000,
                    color: Colors.white,
                  ),
                ),
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

/// Рисуем страны
class CountriesPainter extends CustomPainter {
  final List<Country> countries;

  CountriesPainter(this.countries);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in countries) {
      // Заливка
      final paintFill = Paint()
        ..color = c.color
        ..style = PaintingStyle.fill;
      canvas.drawPath(c.boundary, paintFill);

      // Красная обводка, если воюет
      if (c.atWarWith.isNotEmpty) {
        final borderPaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        canvas.drawPath(c.boundary, borderPaint);
      }

      // Зелёная обводка, если союз
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

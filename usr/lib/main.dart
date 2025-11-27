import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LeapAwayApp());
}

class LeapAwayApp extends StatelessWidget {
  const LeapAwayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leap Away',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        fontFamily: 'Courier',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purpleAccent,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: const TextStyle(fontSize: 18, fontFamily: 'Courier', fontWeight: FontWeight.bold),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/game': (context) => const GameScreen(),
        '/shop': (context) => const ShopScreen(),
        '/upgrades': (context) => const UpgradesScreen(),
        '/modes': (context) => const GameModesScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E0249), Color(0xFF570A57), Color(0xFFA91079)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "LEAP AWAY",
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: Colors.purple, blurRadius: 20, offset: Offset(0, 5))
                  ],
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("START GAME"),
                onPressed: () => Navigator.pushNamed(context, '/game'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.shopping_cart),
                label: const Text("SHOP"),
                onPressed: () => Navigator.pushNamed(context, '/shop'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.upgrade),
                label: const Text("UPGRADES"),
                onPressed: () => Navigator.pushNamed(context, '/upgrades'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.gamepad),
                label: const Text("GAME MODES"),
                onPressed: () => Navigator.pushNamed(context, '/modes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: const Center(
        child: Text('Shop coming soon!', style: TextStyle(fontSize: 24, color: Colors.white)),
      ),
    );
  }
}

class UpgradesScreen extends StatelessWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrades')),
      body: const Center(
        child: Text('Upgrades coming soon!', style: TextStyle(fontSize: 24, color: Colors.white)),
      ),
    );
  }
}

class GameModesScreen extends StatelessWidget {
  const GameModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Modes')),
      body: const Center(
        child: Text('New game modes coming soon!', style: TextStyle(fontSize: 24, color: Colors.white)),
      ),
    );
  }
}


class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game Configuration
  static const double platformSize = 60.0;
  static const double playerSize = 30.0;
  static const double jumpHeight = 80.0;
  static const int initialPlatformCount = 20;

  // Game State
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int coins = 0;
  int currentPlatformIndex = 0;
  
  // Player State
  Offset playerPos = const Offset(0, 0);
  Color playerColor = Colors.cyanAccent;
  
  // World State
  List<PlatformData> platforms = [];
  List<Particle> particles = [];
  
  // Animation
  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _gameLoop;
  
  // Camera
  Offset cameraOffset = const Offset(0, 0);

  @override
  void initState() {
    super.initState();
    
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _jumpAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _jumpController, curve: Curves.easeInOut),
    );

    _jumpController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkLanding();
        _jumpController.reset();
      }
    });

    _initializeGame();
  }

  void _initializeGame() {
    setState(() {
      score = 0;
      currentPlatformIndex = 0;
      platforms = [];
      particles = [];
      isGameOver = false;
      isPlaying = false;
      
      platforms.add(PlatformData(position: const Offset(0, 0), type: PlatformType.normal));
      
      _generatePlatforms(initialPlatformCount);
      
      playerPos = const Offset(0, -playerSize / 2);
      _updateCamera();
    });
  }

  void _generatePlatforms(int count) {
    Offset lastPos = platforms.last.position;
    Random random = Random();

    for (int i = 0; i < count; i++) {
      bool goRight = random.nextBool();
      
      if (goRight) {
        lastPos = Offset(lastPos.dx + platformSize, lastPos.dy);
      } else {
        lastPos = Offset(lastPos.dx, lastPos.dy - platformSize);
      }

      PlatformType type = PlatformType.normal;
      bool hasCoin = false;
      bool hasSpike = false;

      if (random.nextDouble() < 0.1) type = PlatformType.moving;
      if (random.nextDouble() < 0.05) type = PlatformType.crumbling;
      
      if (random.nextDouble() < 0.2) hasCoin = true;
      if (random.nextDouble() < 0.1 && i > 5) hasSpike = true;

      platforms.add(PlatformData(
        position: lastPos,
        type: type,
        hasCoin: hasCoin,
        hasSpike: hasSpike,
      ));
    }
  }

  void _startGame() {
    setState(() {
      isPlaying = true;
    });
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGameLoop();
    });
  }

  void _handleTap() {
    if (isGameOver) return;
    if (!isPlaying) {
      _startGame();
      return;
    }
    if (_jumpController.isAnimating) return;

    if (currentPlatformIndex + 1 < platforms.length) {
      _jumpController.forward();
    }
  }

  void _checkLanding() {
    setState(() {
      currentPlatformIndex++;
      PlatformData landedPlatform = platforms[currentPlatformIndex];
      
      playerPos = Offset(landedPlatform.position.dx, landedPlatform.position.dy - playerSize/2);
      
      if (landedPlatform.hasSpike) {
        _gameOver();
        return;
      }

      if (landedPlatform.hasCoin) {
        coins++;
        landedPlatform.hasCoin = false;
        _spawnParticles(playerPos, Colors.yellow);
      }

      score++;
      
      if (platforms.length - currentPlatformIndex < 10) {
        _generatePlatforms(10);
      }
      
      _updateCamera();
    });
  }

  void _gameOver() {
    setState(() {
      isGameOver = true;
      isPlaying = false;
      _gameLoop?.cancel();
    });
    HapticFeedback.heavyImpact();
  }

  void _updateCamera() {
    // This is calculated in the build method
  }

  void _updateGameLoop() {
    if (!mounted) return;
    setState(() {
      for (var p in particles) {
        p.update();
      }
      particles.removeWhere((p) => p.life <= 0);
    });
  }

  void _spawnParticles(Offset pos, Color color) {
    for (int i = 0; i < 10; i++) {
      particles.add(Particle(
        position: pos,
        color: color,
        velocity: Offset(
          (Random().nextDouble() - 0.5) * 5,
          (Random().nextDouble() - 0.5) * 5,
        ),
      ));
    }
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _gameLoop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    
    Offset renderPlayerPos = playerPos;
    
    if (_jumpController.isAnimating && currentPlatformIndex + 1 < platforms.length) {
      Offset start = platforms[currentPlatformIndex].position;
      Offset end = platforms[currentPlatformIndex + 1].position;
      double t = _jumpAnimation.value;
      
      double currentX = ui.lerpDouble(start.dx, end.dx, t)!;
      double currentY = ui.lerpDouble(start.dy, end.dy, t)!;
      
      double heightOffset = sin(t * pi) * jumpHeight;
      
      renderPlayerPos = Offset(currentX, currentY - heightOffset - playerSize/2);
    }

    double camX = screenSize.width / 2 - renderPlayerPos.dx;
    double camY = screenSize.height / 2 - renderPlayerPos.dy + 100;

    return Scaffold(
      body: GestureDetector(
        onTapDown: (_) => _handleTap(),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E0249), Color(0xFF570A57), Color(0xFFA91079)],
                ),
              ),
            ),

            Transform.translate(
              offset: Offset(camX, camY),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...platforms.asMap().entries.map((entry) {
                    int idx = entry.key;
                    if ((idx - currentPlatformIndex).abs() > 15) return const SizedBox.shrink();
                    
                    return Positioned(
                      left: entry.value.position.dx - platformSize / 2,
                      top: entry.value.position.dy - platformSize / 2,
                      child: _buildPlatform(entry.value),
                    );
                  }),

                  ...particles.map((p) => Positioned(
                    left: p.position.dx,
                    top: p.position.dy,
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: BoxDecoration(
                        color: p.color.withOpacity(p.life),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )),

                  Positioned(
                    left: renderPlayerPos.dx - playerSize / 2,
                    top: renderPlayerPos.dy - playerSize / 2,
                    child: Container(
                      width: playerSize,
                      height: playerSize,
                      decoration: BoxDecoration(
                        color: playerColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: playerColor.withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: playerSize * 0.6,
                          height: playerSize * 0.6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SCORE: $score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.monetization_on, color: Colors.yellow, size: 20),
                                const SizedBox(width: 5),
                                Text(
                                  '$coins',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              playerColor = Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
                            });
                          },
                          icon: const Icon(Icons.person, color: Colors.white),
                          tooltip: 'Change Character',
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (!isPlaying && !isGameOver)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "Tap to Start",
                      style: TextStyle(color: Colors.white70, fontSize: 20),
                    ),
                    SizedBox(height: 10),
                    Icon(Icons.touch_app, color: Colors.white, size: 40),
                  ],
                ),
              ),

            if (isGameOver)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "GAME OVER",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Score: $score",
                        style: const TextStyle(fontSize: 24, color: Colors.white),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _initializeGame,
                        child: const Text("TRY AGAIN"),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                        child: const Text("MAIN MENU"),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatform(PlatformData platform) {
    Color color = Colors.pinkAccent;
    if (platform.type == PlatformType.moving) color = Colors.blueAccent;
    if (platform.type == PlatformType.crumbling) color = Colors.orangeAccent;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: platformSize,
          height: platformSize,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
        ),
        if (platform.hasCoin)
          Positioned(
            top: -20,
            child: Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: Colors.yellow,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.yellowAccent, blurRadius: 5)],
              ),
            ),
          ),
        if (platform.hasSpike)
          const Positioned(
            top: -15,
            child: Icon(Icons.change_history, color: Colors.red, size: 30),
          ),
      ],
    );
  }
}

enum PlatformType { normal, moving, crumbling }

class PlatformData {
  final Offset position;
  final PlatformType type;
  bool hasCoin;
  final bool hasSpike;

  PlatformData({
    required this.position,
    required this.type,
    this.hasCoin = false,
    this.hasSpike = false,
  });
}

class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double life = 1.0;
  double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    this.size = 5.0,
  });

  void update() {
    position += velocity;
    life -= 0.05;
    size *= 0.95;
  }
}

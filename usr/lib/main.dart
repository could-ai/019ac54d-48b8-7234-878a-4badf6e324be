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
        fontFamily: 'Courier', // Arcade style font feel
      ),
      home: const GameScreen(),
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
    
    // Setup Jump Animation
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
      
      // Generate initial platforms
      // First platform is at 0,0
      platforms.add(PlatformData(position: const Offset(0, 0), type: PlatformType.normal));
      
      _generatePlatforms(initialPlatformCount);
      
      // Place player on first platform
      playerPos = const Offset(0, -playerSize / 2);
      _updateCamera();
    });
  }

  void _generatePlatforms(int count) {
    Offset lastPos = platforms.last.position;
    Random random = Random();

    for (int i = 0; i < count; i++) {
      // Decide direction: Right or Forward (Up in 2D view, but looks like zig-zag)
      // For this isometric-like view:
      // Move X+ (Right) or Y- (Up/Forward)
      
      bool goRight = random.nextBool();
      
      if (goRight) {
        lastPos = Offset(lastPos.dx + platformSize, lastPos.dy);
      } else {
        lastPos = Offset(lastPos.dx, lastPos.dy - platformSize);
      }

      // Determine platform type
      PlatformType type = PlatformType.normal;
      bool hasCoin = false;
      bool hasSpike = false;

      if (random.nextDouble() < 0.1) type = PlatformType.moving;
      if (random.nextDouble() < 0.05) type = PlatformType.crumbling;
      
      // Add obstacles/coins
      if (random.nextDouble() < 0.2) hasCoin = true;
      if (random.nextDouble() < 0.1 && i > 5) hasSpike = true; // No spikes at start

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
    // Start game loop for particles and moving platforms
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

    // Determine target platform (the next one in the list)
    if (currentPlatformIndex + 1 < platforms.length) {
      PlatformData target = platforms[currentPlatformIndex + 1];
      
      // Start jump animation
      // We animate the "progress" of the jump manually in the build or listener, 
      // but here we just trigger the controller.
      // The actual position update happens when animation completes for simplicity in this prototype,
      // or we interpolate. Let's interpolate for smoothness.
      
      _jumpController.forward();
    }
  }

  void _checkLanding() {
    setState(() {
      currentPlatformIndex++;
      PlatformData landedPlatform = platforms[currentPlatformIndex];
      
      // Update player position to the center of the platform
      playerPos = Offset(landedPlatform.position.dx, landedPlatform.position.dy - playerSize/2);
      
      // Check for spikes
      if (landedPlatform.hasSpike) {
        _gameOver();
        return;
      }

      // Check for coins
      if (landedPlatform.hasCoin) {
        coins++;
        landedPlatform.hasCoin = false;
        _spawnParticles(playerPos, Colors.yellow);
      }

      score++;
      
      // Generate more platforms as we go
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
    // Vibrate if on mobile
    HapticFeedback.heavyImpact();
  }

  void _updateCamera() {
    // Center the player on screen
    // Screen center is (Width/2, Height/2)
    // We want CameraOffset + PlayerPos = ScreenCenter
    // So CameraOffset = ScreenCenter - PlayerPos
    // We'll calculate this in the build method using MediaQuery
  }

  void _updateGameLoop() {
    if (!mounted) return;
    setState(() {
      // Update particles
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
    
    // Calculate camera offset to center player
    // We interpolate player position based on jump animation
    Offset renderPlayerPos = playerPos;
    
    if (_jumpController.isAnimating && currentPlatformIndex + 1 < platforms.length) {
      Offset start = platforms[currentPlatformIndex].position;
      Offset end = platforms[currentPlatformIndex + 1].position;
      double t = _jumpAnimation.value;
      
      // Linear interpolation for X and Y
      double currentX = ui.lerpDouble(start.dx, end.dx, t)!;
      double currentY = ui.lerpDouble(start.dy, end.dy, t)!;
      
      // Add jump arc (parabola) to Y
      // Height peaks at t=0.5
      double heightOffset = sin(t * pi) * jumpHeight;
      
      renderPlayerPos = Offset(currentX, currentY - heightOffset - playerSize/2);
    }

    // Camera follows player
    double camX = screenSize.width / 2 - renderPlayerPos.dx;
    double camY = screenSize.height / 2 - renderPlayerPos.dy + 100; // +100 to look slightly ahead/down

    return Scaffold(
      body: GestureDetector(
        onTapDown: (_) => _handleTap(),
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E0249), Color(0xFF570A57), Color(0xFFA91079)],
                ),
              ),
            ),

            // Game World
            Transform.translate(
              offset: Offset(camX, camY),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Draw Platforms
                  ...platforms.asMap().entries.map((entry) {
                    int idx = entry.key;
                    // Optimization: Only draw visible platforms (rough estimate)
                    if ((idx - currentPlatformIndex).abs() > 15) return const SizedBox.shrink();
                    
                    return Positioned(
                      left: entry.value.position.dx - platformSize / 2,
                      top: entry.value.position.dy - platformSize / 2,
                      child: _buildPlatform(entry.value),
                    );
                  }),

                  // Draw Particles
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

                  // Draw Player
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

            // UI Overlay
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
                        // Character Unlock Button (Mockup)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              // Random color change to simulate character switch
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

            // Start / Game Over Screen
            if (!isPlaying && !isGameOver)
              Center(
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
                    const SizedBox(height: 20),
                    const Text(
                      "Tap to Start",
                      style: TextStyle(color: Colors.white70, fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    const Icon(Icons.touch_app, color: Colors.white, size: 40),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        ),
                        child: const Text("TRY AGAIN", style: TextStyle(fontSize: 20)),
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
        // The Platform
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
        // Coin
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
        // Spike
        if (platform.hasSpike)
          Positioned(
            top: -15,
            child: Icon(Icons.change_history, color: Colors.red, size: 30),
          ),
      ],
    );
  }
}

// --- Data Models ---

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

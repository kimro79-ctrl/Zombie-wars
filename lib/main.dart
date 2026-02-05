import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart'; 
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: ZombieGame()));
}

class ZombieGame extends FlameGame with PanDetector {
  late RectangleComponent player;
  final List<RectangleComponent> clones = [];
  double spawnTimer = 0;
  double shootTimer = 0;
  double gameTime = 0; 
  
  int score = 0;
  double laserWidth = 8.0;

  late TextComponent statusText;

  @override
  Future<void> onLoad() async {
    player = RectangleComponent()
      ..size = Vector2(40, 40)
      ..position = Vector2(size.x / 2 - 20, size.y - 120)
      ..paint = (Paint()..color = Colors.cyan);
    add(player);

    statusText = TextComponent(
      text: '',
      position: Vector2(20, 50),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
    add(statusText);
  }

  void addClone() {
    final clone = RectangleComponent()
      ..size = Vector2(30, 30)
      ..paint = (Paint()..color = Colors.cyan.withOpacity(0.5));
    clones.add(clone);
    add(clone);
  }

  @override
  void onPanUpdate(DragUpdateEvent info) {
    player.position.x += info.localDelta.x;
    player.position.x = player.position.x.clamp(0.0, size.x - player.size.x);
    
    for (int i = 0; i < clones.length; i++) {
      double offset = (i % 2 == 0) ? -(60.0 + (i ~/ 2) * 50) : (60.0 + (i ~/ 2) * 50);
      clones[i].position.x = player.position.x + offset;
      clones[i].position.y = player.position.y + 20;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    
    // 1분 게임에 맞춰 12초마다 분신 추가 (최대 4마리)
    int expectedClones = (gameTime / 12).floor();
    if (clones.length < expectedClones && clones.length < 4) {
      addClone();
    }

    // 시간 경과에 따른 레이저 강화 (더 빠르게 굵어짐)
    laserWidth = (8.0 + (gameTime / 2)).clamp(8.0, 60.0);

    // 좀비 생성: 60초(1분) 동안 난이도가 매우 빠르게 상승
    spawnTimer += dt;
    double difficultyFactor = (gameTime / 60.0).clamp(0.0, 1.0); 
    double spawnInterval = (0.22 - (difficultyFactor * 0.20)).clamp(0.02, 0.22);
    
    if (spawnTimer > spawnInterval) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50), gameTime));
      spawnTimer = 0;
    }

    // 레이저 발사
    shootTimer += dt;
    if (shootTimer > 0.12) {
      add(Laser(Vector2(player.x + 20 - (laserWidth / 2), player.y), laserWidth));
      for (var clone in clones) {
        add(Laser(Vector2(clone.x + 15 - (laserWidth / 3), clone.y), laserWidth * 0.7));
      }
      shootTimer = 0;
    }
    
    int seconds = gameTime.toInt();
    int remaining = max(0, 60 - seconds);
    statusText.text = 'REMAINING: ${remaining}s  SCORE: $score  CLONES: ${clones.length}';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  final double gameTimeAtSpawn;
  Zombie(Vector2 position, this.gameTimeAtSpawn) : super(position: position, size: Vector2(40, 40)) {
    paint = Paint()..color = Colors.redAccent;
  }
  @override
  void update(double dt) {
    super.update(dt);
    // 1분 모드에 맞춰 속도 증가폭 상향
    double speed = 180 + (gameTimeAtSpawn * 3.0);
    y += speed * dt;
    if (y > gameRef.size.y) removeFromParent();

    gameRef.children.whereType<Laser>().forEach((laser) {
      if (toRect().overlaps(laser.toRect())) {
        gameRef.score += 10;
        removeFromParent(); 
      }
    });
  }
}

class Laser extends RectangleComponent {
  Laser(Vector2 position, double width) : super(position: position, size: Vector2(width, 40)) {
    paint = Paint()
      ..color = Colors.red
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5);
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 1200 * dt; 
    if (y < -50) removeFromParent();
  }
}

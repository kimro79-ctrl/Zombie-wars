import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart'; // PanDetector를 위해 필수
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

  // 오류 해결 포인트: 가장 안정적인 DragUpdateInfo 문법 사용
  @override
  void onPanUpdate(DragUpdateInfo info) {
    player.position.x += info.delta.global.x;
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
    
    // 1분(60초) 게임: 12초마다 분신 추가 (최대 4마리)
    int expectedClones = (gameTime / 12).floor();
    if (clones.length < expectedClones && clones.length < 4) {
      addClone();
    }

    // 시간 경과에 따라 레이저가 조금씩 굵어짐
    laserWidth = (8.0 + (gameTime / 2.5)).clamp(8.0, 55.0);

    // 좀비 생성: 시간이 흐를수록 난이도 상승 (0.22초 -> 0.04초 간격)
    spawnTimer += dt;
    double difficultyFactor = (gameTime / 60.0).clamp(0.0, 1.0); 
    double spawnInterval = (0.22 - (difficultyFactor * 0.18)).clamp(0.04, 0.22);
    
    if (spawnTimer > spawnInterval) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50), gameTime));
      spawnTimer = 0;
    }

    // 관통 레이저 발사 (0.13초 간격)
    shootTimer += dt;
    if (shootTimer > 0.13) {
      add(Laser(Vector2(player.x + 20 - (laserWidth / 2), player.y), laserWidth));
      for (var clone in clones) {
        add(Laser(Vector2(clone.x + 15 - (laserWidth / 3), clone.y), laserWidth * 0.7));
      }
      shootTimer = 0;
    }
    
    int remaining = max(0, 60 - gameTime.toInt());
    statusText.text = 'REMAINING: ${remaining}s  SCORE: $score';
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
    // 시간에 따라 내려오는 속도가 조금씩 빨라짐
    double speed = 170 + (gameTimeAtSpawn * 2.5);
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
    y -= 1150 * dt; 
    if (y < -50) removeFromParent();
  }
}

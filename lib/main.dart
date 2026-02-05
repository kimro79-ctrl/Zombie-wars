import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: ZombieGame()));
}

class ZombieGame extends FlameGame with PanDetector {
  late RectangleComponent player;
  final List<RectangleComponent> clones = [];
  double spawnTimer = 0;
  double shootTimer = 0;
  double gameTime = 0; // 게임 진행 시간 (초)
  
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
  void onPanUpdate(DragUpdateInfo info) {
    // 이동 로직: clamp를 사용하여 화면 밖으로 나가지 않게 고정
    player.position.x += info.delta.global.x;
    player.position.x = player.position.x.clamp(0.0, size.x - player.size.x);
    
    // 분신 이동 동기화
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
    
    // 30초마다 분신 추가 (최대 4마리)
    int expectedClones = (gameTime / 30).floor();
    if (clones.length < expectedClones && clones.length < 4) {
      addClone();
    }

    // 시간이 지날수록 레이저 미세 강화
    laserWidth = min(40.0, 8.0 + (gameTime / 10));

    // 좀비 생성: 시간이 흐를수록, 특히 120초 이후 급격히 어려워짐
    spawnTimer += dt;
    double difficultyFactor = min(1.0, gameTime / 120.0); // 0.0 ~ 1.0 (2분까지)
    double spawnInterval = max(0.02, 0.25 - (difficultyFactor * 0.23));
    
    if (spawnTimer > spawnInterval) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50), gameTime));
      spawnTimer = 0;
    }

    // 본체 및 분신 레이저 발사
    shootTimer += dt;
    if (shootTimer > 0.15) {
      add(Laser(Vector2(player.x + 20 - (laserWidth / 2), player.y), laserWidth));
      for (var clone in clones) {
        add(Laser(Vector2(clone.x + 15 - (laserWidth / 3), clone.y), laserWidth * 0.7));
      }
      shootTimer = 0;
    }
    
    int minutes = (gameTime / 60).floor();
    int seconds = (gameTime % 60).toInt();
    statusText.text = 'TIME: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}  SCORE: $score  CLONES: ${clones.length}';
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
    // 생존 시간이 길어질수록 좀비 이동 속도 증가
    double speed = 160 + (gameTimeAtSpawn * 0.8);
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
  Laser(Vector2 position, double width) : super(position: position, size: Vector2(width, 35)) {
    paint = Paint()
      ..color = Colors.red
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5);
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 1000 * dt;
    if (y < -50) removeFromParent();
  }
}

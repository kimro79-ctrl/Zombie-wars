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
  double spawnTimer = 0;
  double shootTimer = 0;
  double laserWidth = 4.0; // 레이저 기본 굵기
  int score = 0;
  late TextComponent scoreText;

  @override
  Future<void> onLoad() async {
    player = RectangleComponent()
      ..size = Vector2(40, 40)
      ..position = Vector2(size.x / 2 - 20, size.y - 120)
      ..paint = (Paint()..color = Colors.cyan);
    add(player);

    scoreText = TextComponent(
      text: 'SCORE: 0  LASER LV: 1',
      position: Vector2(20, 50),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
    );
    add(scoreText);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    // 세밀한 조작: 손가락 움직임에 1:1 대응
    player.position.x += info.delta.global.x;
    player.position.x = player.position.x.clamped(0, size.x - player.size.x);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // 좀비 떼 생성: 매우 빠른 속도로 소환
    spawnTimer += dt;
    double spawnInterval = max(0.05, 0.3 - (score / 5000)); 
    if (spawnTimer > spawnInterval) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50)));
      spawnTimer = 0;
    }

    // 레이저 발사 로직
    shootTimer += dt;
    if (shootTimer > 0.1) { // 빠른 발사 속도
      add(Laser(Vector2(player.x + 20 - (laserWidth / 2), player.y), laserWidth));
      shootTimer = 0;
    }
    
    scoreText.text = 'SCORE: $score  LASER LV: ${(laserWidth/4).Int()}';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  Zombie(Vector2 position) : super(position: position, size: Vector2(40, 40)) {
    paint = Paint()..color = Colors.redAccent;
  }
  @override
  void update(double dt) {
    super.update(dt);
    // 아래로 내려오는 속도 증가
    y += (180 + (gameRef.score * 0.4)) * dt;
    if (y > gameRef.size.y) removeFromParent();

    // 레이저와 충돌 판정
    gameRef.children.whereType<Laser>().forEach((laser) {
      if (toRect().overlaps(laser.toRect())) {
        gameRef.score += 10;
        removeFromParent(); // 좀비는 죽지만 레이저는 사라지지 않고 관통함
        if (Random().nextDouble() < 0.05) gameRef.add(Item(position));
      }
    });
  }
}

class Laser extends RectangleComponent {
  Laser(Vector2 position, double width) : super(position: position, size: Vector2(width, 20)) {
    // 레이저 색상: 붉은색 강렬한 빛
    paint = Paint()
      ..color = Colors.red
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 800 * dt; // 레이저 이동 속도
    if (y < -50) removeFromParent();
  }
}

class Item extends RectangleComponent with HasGameRef<ZombieGame> {
  Item(Vector2 position) : super(position: position, size: Vector2(25, 25)) {
    paint = Paint()..color = Colors.pinkAccent;
  }
  @override
  void update(double dt) {
    super.update(dt);
    y += 150 * dt;
    if (toRect().overlaps(gameRef.player.toRect())) {
      // 아이템 획득 시 레이저가 굵어짐 (최대 40까지)
      if (gameRef.laserWidth < 40) gameRef.laserWidth += 4;
      removeFromParent();
    }
  }
}

extension on double {
  int Int() => toInt();
}

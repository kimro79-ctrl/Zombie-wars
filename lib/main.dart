import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: ZombieGame()));
}

class ZombieGame extends FlameGame with PanDetector, HasCollisionDetection {
  late RectangleComponent player;
  double spawnTimer = 0;
  double shootTimer = 0;
  int multiCount = 1; // 1 -> 2 -> 6 -> 12로 증가할 변수
  int score = 0;
  late TextComponent scoreText;

  @override
  Future<void> onLoad() async {
    // 플레이어 설정
    player = RectangleComponent()
      ..size = Vector2(40, 40)
      ..position = Vector2(size.x / 2 - 20, size.y - 100)
      ..paint = (Paint()..color = Colors.cyan);
    add(player);

    scoreText = TextComponent(
      text: 'KILLS: 0  GUNS: 1',
      position: Vector2(20, 40),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20)),
    );
    add(scoreText);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    player.position.x += info.delta.global.x;
    player.position.x = player.position.x.clamp(0, size.x - player.size.x);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // 1. 좀비 스폰
    spawnTimer += dt;
    if (spawnTimer > max(0.2, 0.8 - (score / 500))) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50)));
      spawnTimer = 0;
    }

    // 2. 자동 사격 (multiCount만큼 옆으로 나란히 발사)
    shootTimer += dt;
    if (shootTimer > 0.2) {
      double spacing = 25.0; // 총구 간격
      double startX = player.x - ((multiCount - 1) * spacing / 2) + 15;
      
      for (int i = 0; i < multiCount; i++) {
        add(Bullet(Vector2(startX + (i * spacing), player.y)));
      }
      shootTimer = 0;
    }

    scoreText.text = 'KILLS: $score  GUNS: $multiCount';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  Zombie(Vector2 position) : super(position: position, size: Vector2(40, 40)) {
    paint = Paint()..color = Colors.redAccent;
  }

  @override
  void update(double dt) {
    super.update(dt);
    y += (150 + gameRef.score) * dt;
    if (y > gameRef.size.y) removeFromParent();

    // 좀비를 죽일 때 확률적으로 아이템 생성
    gameRef.children.whereType<Bullet>().forEach((bullet) {
      if (toRect().overlaps(bullet.toRect())) {
        gameRef.score += 1;
        bullet.removeFromParent();
        removeFromParent();
        
        if (Random().nextDouble() < 0.1) { // 10% 확률로 아이템
          gameRef.add(Item(position));
        }
      }
    });
  }
}

class Bullet extends RectangleComponent {
  Bullet(Vector2 position) : super(position: position, size: Vector2(8, 20)) {
    paint = Paint()..color = Colors.yellow;
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 600 * dt;
    if (y < -20) removeFromParent();
  }
}

class Item extends RectangleComponent with HasGameRef<ZombieGame> {
  Item(Vector2 position) : super(position: position, size: Vector2(30, 30)) {
    paint = Paint()..color = Colors.blue;
  }
  @override
  void update(double dt) {
    super.update(dt);
    y += 100 * dt;
    if (toRect().overlaps(gameRef.player.toRect())) {
      // 아이템 먹으면 1 -> 2 -> 6 -> 12로 진화
      if (gameRef.multiCount == 1) gameRef.multiCount = 2;
      else if (gameRef.multiCount == 2) gameRef.multiCount = 6;
      else if (gameRef.multiCount == 6) gameRef.multiCount = 12;
      removeFromParent();
    }
  }
}

import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart'; // 이벤트 패키지 추가
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: ZombieGame()));
}

class ZombieGame extends FlameGame with PanDetector {
  late RectangleComponent player;
  double spawnTimer = 0;
  double shootTimer = 0;
  int multiCount = 1; 
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
      text: 'SCORE: 0  GUNS: 1',
      position: Vector2(20, 50),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20)),
    );
    add(scoreText);
  }

  // 이 부분이 에러의 핵심이었습니다. 타입을 정확히 맞췄습니다.
  @override
  void onPanUpdate(DragUpdateInfo info) {
    player.position.x += info.delta.global.x;
    player.position.x = player.position.x.clamp(0, size.x - player.size.x);
  }

  @override
  void update(double dt) {
    super.update(dt);
    spawnTimer += dt;
    if (spawnTimer > max(0.2, 0.8 - (score / 1000))) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50)));
      spawnTimer = 0;
    }

    shootTimer += dt;
    if (shootTimer > 0.25) {
      double spacing = 25.0;
      double startX = player.x - ((multiCount - 1) * spacing / 2) + 15;
      for (int i = 0; i < multiCount; i++) {
        add(Bullet(Vector2(startX + (i * spacing), player.y)));
      }
      shootTimer = 0;
    }
    scoreText.text = 'SCORE: $score  GUNS: $multiCount';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  Zombie(Vector2 position) : super(position: position, size: Vector2(40, 40)) {
    paint = Paint()..color = Colors.redAccent;
  }
  @override
  void update(double dt) {
    super.update(dt);
    y += (150 + (gameRef.score * 0.5)) * dt;
    if (y > gameRef.size.y) removeFromParent();

    gameRef.children.whereType<Bullet>().forEach((bullet) {
      if (toRect().overlaps(bullet.toRect())) {
        gameRef.score += 10;
        bullet.removeFromParent();
        removeFromParent();
        if (Random().nextDouble() < 0.15) gameRef.add(Item(position));
      }
    });
  }
}

class Bullet extends RectangleComponent {
  Bullet(Vector2 position) : super(position: position, size: Vector2(10, 20)) {
    paint = Paint()..color = Colors.yellow;
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 500 * dt;
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
    y += 120 * dt;
    if (toRect().overlaps(gameRef.player.toRect())) {
      if (gameRef.multiCount == 1) gameRef.multiCount = 2;
      else if (gameRef.multiCount == 2) gameRef.multiCount = 6;
      else if (gameRef.multiCount == 6) gameRef.multiCount = 12;
      removeFromParent();
    }
  }
}

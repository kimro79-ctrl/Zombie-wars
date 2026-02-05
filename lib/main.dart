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
  late RectangleComponent fence;
  final List<RectangleComponent> clones = [];
  
  double spawnTimer = 0;
  double shootTimer = 0;
  double gameTime = 0; 
  double bossTimer = 0; 
  int bossCount = 0;
  int score = 0;
  int fenceHp = 100; // 펜스 체력

  double laserWidth = 5.0; // 픽셀 축소에 맞춰 조정
  double shootInterval = 0.12;
  Set<int> unlockedMilestones = {};

  late TextComponent statusText;

  @override
  Future<void> onLoad() async {
    // 픽셀 크기 축소: 플레이어 30x30
    player = RectangleComponent()
      ..size = Vector2(30, 30)
      ..position = Vector2(size.x * 0.7, size.y - 80)
      ..paint = (Paint()..color = Colors.cyan);
    add(player);

    // 하단 1/3 지점 펜스 생성
    fence = RectangleComponent()
      ..size = Vector2(size.x * 0.6, 10)
      ..position = Vector2(size.x * 0.4, size.y * 0.7)
      ..paint = (Paint()..color = Colors.orange.withOpacity(0.8));
    add(fence);

    statusText = TextComponent(
      text: '',
      position: Vector2(size.x * 0.42, 30),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
    add(statusText);

    add(RectangleComponent()
      ..size = Vector2(2, size.y)
      ..position = Vector2(size.x * 0.4, 0)
      ..paint = (Paint()..color = Colors.white10));
  }

  void addInventoryItem(String name, double yPos) {
    add(TextComponent(
      text: "[$name]",
      position: Vector2(15, yPos),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.yellowAccent, fontSize: 14)),
    ));
  }

  @override
  void onPanUpdate(dynamic info) {
    final deltaX = info.delta.global.x;
    player.position.x += deltaX;
    player.position.x = player.position.x.clamp(size.x * 0.4, size.x - player.size.x);
    
    for (int i = 0; i < clones.length; i++) {
      double offset = (i == 0) ? -40.0 : 40.0;
      clones[i].position.x = (player.position.x + offset).clamp(size.x * 0.4, size.x - 25);
      clones[i].position.y = player.position.y + 5;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    bossTimer += dt;

    if (score >= 1000 && !unlockedMilestones.contains(1000)) {
      unlockedMilestones.add(1000); addInventoryItem("🚀 바주카", 100); laserWidth = 12.0;
    }
    if (score >= 5000 && !unlockedMilestones.contains(5000)) {
      unlockedMilestones.add(5000); addInventoryItem("🚜 탱크", 150); laserWidth = 25.0; shootInterval = 0.09;
    }
    if (score >= 20000 && !unlockedMilestones.contains(20000)) {
      unlockedMilestones.add(20000); addInventoryItem("☢️ 핵미사일", 200); laserWidth = 70.0; shootInterval = 0.06;
    }

    // 점수 비례 좀비 생성 가속 (기본 0.05초에서 점수가 오를수록 극도로 빨라짐)
    spawnTimer += dt;
    double scoreFactor = (score / 30000).clamp(0.0, 1.0);
    double currentInterval = (0.05 - (scoreFactor * 0.04)).clamp(0.01, 0.05);
    
    if (spawnTimer > currentInterval) {
      double spawnX = (size.x * 0.41) + (Random().nextDouble() * (size.x * 0.59 - 25));
      add(Zombie(Vector2(spawnX, -30), isBoss: false, bossGen: bossCount));
      spawnTimer = 0;
    }

    if (bossTimer >= 15.0) {
      bossCount++;
      double spawnX = (size.x * 0.5) + (Random().nextDouble() * (size.x * 0.4 - 60));
      add(Zombie(Vector2(spawnX, -60), isBoss: true, bossGen: bossCount));
      bossTimer = 0;
    }

    if (gameTime > 10 && clones.length < 1) {
      final c = RectangleComponent()..size = Vector2(25,25)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }
    if (gameTime > 25 && clones.length < 2) {
      final c = RectangleComponent()..size = Vector2(25,25)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }

    shootTimer += dt;
    if (shootTimer > shootInterval) {
      add(Laser(Vector2(player.x + 15 - (laserWidth/2), player.y), laserWidth));
      for (var c in clones) add(Laser(Vector2(c.x + 12 - (laserWidth*0.5/2), c.y), laserWidth * 0.5));
      shootTimer = 0;
    }
    
    // 펜스 파괴 체크 및 색상 변경
    if (fenceHp <= 0 && fence.parent != null) {
      fence.removeFromParent();
    } else if (fenceHp > 0) {
      fence.paint.color = Colors.orange.withOpacity((fenceHp / 100).clamp(0.2, 0.8));
    }

    int remaining = max(0, 60 - gameTime.toInt());
    statusText.text = 'TIME: ${remaining}s FENCE: $fenceHp%\nSCORE: $score';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  final bool isBoss;
  int hp;

  Zombie(Vector2 pos, {required this.isBoss, required int bossGen}) 
      : hp = isBoss ? (25 + (bossGen * 15)) : (1 + (gameRef.score ~/ 10000)), 
        super(position: pos, size: isBoss ? Vector2(60, 60) : Vector2(20, 20)) {
    paint = Paint()..color = isBoss ? Colors.purpleAccent : Colors.redAccent;
  }

  @override
  void update(double dt) {
    super.update(dt);
    double speed = isBoss ? 60 : 220 + (gameRef.gameTime * 3);
    y += speed * dt;
    
    // 펜스 충돌 판정
    if (gameRef.fenceHp > 0 && toRect().overlaps(gameRef.fence.toRect())) {
      gameRef.fenceHp -= isBoss ? 10 : 1;
      removeFromParent();
    }

    if (y > gameRef.size.y) removeFromParent();

    gameRef.children.whereType<Laser>().forEach((laser) {
      if (toRect().overlaps(laser.toRect())) {
        hp--;
        laser.removeFromParent(); 
        if (hp <= 0) {
          gameRef.score += isBoss ? 2000 : 30;
          removeFromParent();
        }
      }
    });
  }
}

class Laser extends RectangleComponent {
  Laser(Vector2 pos, double w) : super(position: pos, size: Vector2(w, 30)) {
    paint = Paint()..color = Colors.yellow..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 1200 * dt;
    if (y < -50) removeFromParent();
  }
}

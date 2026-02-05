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
  double gameTime = 0; 
  double bossTimer = 0; 
  int bossCount = 0; // 보스 출현 횟수 카운트
  int score = 0;
  
  double laserWidth = 8.0;
  double shootInterval = 0.13;
  Set<int> unlockedMilestones = {};

  late TextComponent statusText;

  @override
  Future<void> onLoad() async {
    player = RectangleComponent()
      ..size = Vector2(40, 40)
      ..position = Vector2(size.x * 0.7, size.y - 120)
      ..paint = (Paint()..color = Colors.cyan);
    add(player);

    statusText = TextComponent(
      text: '',
      position: Vector2(size.x * 0.45, 40),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
      position: Vector2(20, yPos),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.yellowAccent, fontSize: 16)),
    ));
  }

  @override
  void onPanUpdate(dynamic info) {
    final deltaX = info.delta.global.x;
    player.position.x += deltaX;
    player.position.x = player.position.x.clamp(size.x * 0.4, size.x - player.size.x);
    
    for (int i = 0; i < clones.length; i++) {
      double offset = (i == 0) ? -50.0 : 50.0;
      clones[i].position.x = (player.position.x + offset).clamp(size.x * 0.4, size.x - 30);
      clones[i].position.y = player.position.y + 10;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    bossTimer += dt;

    // 점수별 무기 해금 및 화력 강화
    if (score >= 1000 && !unlockedMilestones.contains(1000)) {
      unlockedMilestones.add(1000); addInventoryItem("🚀 바주카", 100); laserWidth = 18.0;
    }
    if (score >= 5000 && !unlockedMilestones.contains(5000)) {
      unlockedMilestones.add(5000); addInventoryItem("🚜 탱크", 150); laserWidth = 35.0; shootInterval = 0.10;
    }
    if (score >= 15000 && !unlockedMilestones.contains(15000)) {
      unlockedMilestones.add(15000); addInventoryItem("☢️ 핵미사일", 200); laserWidth = 90.0; shootInterval = 0.07;
    }

    // 좀비 초반 군집 (매우 빠른 생성)
    spawnTimer += dt;
    if (spawnTimer > 0.06) {
      double spawnX = (size.x * 0.42) + (Random().nextDouble() * (size.x * 0.58 - 35));
      add(Zombie(Vector2(spawnX, -50), isBoss: false, bossGen: bossCount));
      spawnTimer = 0;
    }

    // 15초마다 강화되는 보스 등장
    if (bossTimer >= 15.0) {
      bossCount++; // 보스 회차 증가
      double spawnX = (size.x * 0.5) + (Random().nextDouble() * (size.x * 0.4 - 80));
      add(Zombie(Vector2(spawnX, -80), isBoss: true, bossGen: bossCount));
      bossTimer = 0;
    }

    // 분신 및 발사 로직 (생략 없는 핵심 로직)
    if (gameTime > 10 && clones.length < 1) {
      final c = RectangleComponent()..size = Vector2(30,30)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }
    if (gameTime > 25 && clones.length < 2) {
      final c = RectangleComponent()..size = Vector2(30,30)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }

    shootTimer += dt;
    if (shootTimer > shootInterval) {
      add(Laser(Vector2(player.x + 20 - (laserWidth/2), player.y), laserWidth));
      for (var c in clones) add(Laser(Vector2(c.x + 15 - (laserWidth*0.5/2), c.y), laserWidth * 0.5));
      shootTimer = 0;
    }
    
    int remaining = max(0, 60 - gameTime.toInt());
    statusText.text = 'TIME: ${remaining}s  BOSS: v$bossCount\nSCORE: $score';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  final bool isBoss;
  int hp;

  Zombie(Vector2 pos, {required this.isBoss, required int bossGen}) 
      : hp = isBoss ? (15 + (bossGen * 10)) : 1, // 보스는 회차당 10방씩 체력 증가
        super(position: pos, size: isBoss ? Vector2(80, 80) : Vector2(30, 30)) {
    paint = Paint()..color = isBoss ? Colors.purple : Colors.redAccent;
  }

  @override
  void update(double dt) {
    super.update(dt);
    double speed = isBoss ? 70 : 190 + (gameRef.gameTime * 2.5);
    y += speed * dt;
    if (y > gameRef.size.y) removeFromParent();

    gameRef.children.whereType<Laser>().forEach((laser) {
      if (toRect().overlaps(laser.toRect())) {
        hp--;
        laser.removeFromParent(); 
        if (isBoss) paint.color = Colors.purple.withBlue((255 - (hp * 5)).clamp(0, 255));
        if (hp <= 0) {
          gameRef.score += isBoss ? (500 * (hp + 1)) : 20; // 보스 보상도 증가
          removeFromParent();
        }
      }
    });
  }
}

class Laser extends RectangleComponent {
  Laser(Vector2 pos, double w) : super(position: pos, size: Vector2(w, 40)) {
    paint = Paint()..color = Colors.yellowAccent..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 1150 * dt;
    if (y < -50) removeFromParent();
  }
}

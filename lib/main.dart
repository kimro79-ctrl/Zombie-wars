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
  double fenceHp = 150.0; // 펜스 체력 상향

  double laserWidth = 4.0; // 픽셀 축소에 맞춤
  double shootInterval = 0.12;
  Set<int> unlockedMilestones = {};

  late TextComponent statusText;

  @override
  Future<void> onLoad() async {
    // 픽셀 크기 더 축소: 플레이어 25x25
    player = RectangleComponent()
      ..size = Vector2(25, 25)
      ..position = Vector2(size.x * 0.7, size.y - 80)
      ..paint = (Paint()..color = Colors.cyan);
    add(player);

    // 하단 1/3 지점 펜스
    fence = RectangleComponent()
      ..size = Vector2(size.x * 0.6, 8)
      ..position = Vector2(size.x * 0.4, size.y * 0.75)
      ..paint = (Paint()..color = Colors.orange.withOpacity(0.8));
    add(fence);

    statusText = TextComponent(
      text: '',
      position: Vector2(size.x * 0.42, 30),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
    add(statusText);

    add(RectangleComponent()
      ..size = Vector2(1, size.y)
      ..position = Vector2(size.x * 0.4, 0)
      ..paint = (Paint()..color = Colors.white10));
  }

  void addInventoryItem(String name, double yPos) {
    add(TextComponent(
      text: "[$name]",
      position: Vector2(10, yPos),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.yellowAccent, fontSize: 13)),
    ));
  }

  @override
  void onPanUpdate(dynamic info) {
    final deltaX = info.delta.global.x;
    player.position.x += deltaX;
    player.position.x = player.position.x.clamp(size.x * 0.4, size.x - player.size.x);
    
    for (int i = 0; i < clones.length; i++) {
      double offset = (i == 0) ? -35.0 : 35.0;
      clones[i].position.x = (player.position.x + offset).clamp(size.x * 0.4, size.x - 20);
      clones[i].position.y = player.position.y + 5;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    bossTimer += dt;

    if (score >= 1000 && !unlockedMilestones.contains(1000)) {
      unlockedMilestones.add(1000); addInventoryItem("🚀 바주카", 100); laserWidth = 10.0;
    }
    if (score >= 5000 && !unlockedMilestones.contains(5000)) {
      unlockedMilestones.add(5000); addInventoryItem("🚜 탱크", 150); laserWidth = 22.0; shootInterval = 0.09;
    }
    if (score >= 20000 && !unlockedMilestones.contains(20000)) {
      unlockedMilestones.add(20000); addInventoryItem("☢️ 핵미사일", 200); laserWidth = 80.0; shootInterval = 0.06;
    }

    // 점수 비례 좀비 생성 가속: 0.04초에서 최저 0.008초까지 가속
    spawnTimer += dt;
    double scoreFactor = (score / 40000).clamp(0.0, 1.0);
    double currentInterval = (0.04 - (scoreFactor * 0.032)).clamp(0.008, 0.04);
    
    if (spawnTimer > currentInterval) {
      double spawnX = (size.x * 0.41) + (Random().nextDouble() * (size.x * 0.59 - 20));
      add(Zombie(Vector2(spawnX, -20), isBoss: false, bossGen: bossCount));
      spawnTimer = 0;
    }

    if (bossTimer >= 15.0) {
      bossCount++;
      double spawnX = (size.x * 0.5) + (Random().nextDouble() * (size.x * 0.4 - 50));
      add(Zombie(Vector2(spawnX, -50), isBoss: true, bossGen: bossCount));
      bossTimer = 0;
    }

    if (gameTime > 10 && clones.length < 1) {
      final c = RectangleComponent()..size = Vector2(20,20)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }
    if (gameTime > 25 && clones.length < 2) {
      final c = RectangleComponent()..size = Vector2(20,20)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }

    shootTimer += dt;
    if (shootTimer > shootInterval) {
      add(Laser(Vector2(player.x + 12 - (laserWidth/2), player.y), laserWidth));
      for (var c in clones) add(Laser(Vector2(c.x + 10 - (laserWidth*0.5/2), c.y), laserWidth * 0.5));
      shootTimer = 0;
    }
    
    if (fenceHp <= 0 && fence.parent != null) {
      fence.removeFromParent();
    } else if (fenceHp > 0) {
      fence.paint.color = Colors.orange.withOpacity((fenceHp / 150).clamp(0.2, 0.8));
    }

    int remaining = max(0, 60 - gameTime.toInt());
    statusText.text = 'TIME: ${remaining}s FENCE: ${((fenceHp/150)*100).toInt()}%\nSCORE: $score';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  final bool isBoss;
  int hp;

  Zombie(Vector2 pos, {required this.isBoss, required int bossGen}) 
      : hp = 0, // 초기값 설정
        super(position: pos, size: isBoss ? Vector2(50, 50) : Vector2(15, 15)) {
    // 빌드 오류 해결: (score ~/ 10000)을 toInt()로 확실하게 정수화
    hp = isBoss ? (30 + (bossGen * 20)) : (1 + (gameRef.score ~/ 8000).toInt());
    paint = Paint()..color = isBoss ? Colors.purpleAccent : Colors.redAccent;
  }

  @override
  void update(double dt) {
    super.update(dt);
    double speed = isBoss ? 55 : 230 + (gameRef.gameTime * 3.5);
    y += speed * dt;
    
    if (gameRef.fenceHp > 0 && toRect().overlaps(gameRef.fence.toRect())) {
      gameRef.fenceHp -=

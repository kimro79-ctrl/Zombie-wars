import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: ZombieGame()));
}

// 1. 레이저 클래스를 상단으로 이동하여 인식 문제 해결
class Laser extends RectangleComponent {
  Laser(Vector2 pos, double w) : super(position: pos, size: Vector2(w, 20)) {
    paint = Paint()..color = Colors.yellow..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);
  }
  @override
  void update(double dt) {
    super.update(dt);
    y -= 1300 * dt;
    if (y < -40) removeFromParent();
  }
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
  double fenceHp = 200.0; // 펜스 체력 강화

  double laserWidth = 3.5; // 픽셀 물량에 맞춰 축소
  double shootInterval = 0.12;
  Set<int> unlockedMilestones = {};

  late TextComponent statusText;

  @override
  Future<void> onLoad() async {
    // 플레이어 크기 20x20으로 축소 (픽셀 느낌 극대화)
    player = RectangleComponent()
      ..size = Vector2(20, 20)
      ..position = Vector2(size.x * 0.7, size.y - 60)
      ..paint = (Paint()..color = Colors.cyan);
    add(player);

    // 하단 1/3 지점 펜스
    fence = RectangleComponent()
      ..size = Vector2(size.x * 0.6, 6)
      ..position = Vector2(size.x * 0.4, size.y * 0.75)
      ..paint = (Paint()..color = Colors.orange);
    add(fence);

    statusText = TextComponent(
      text: '',
      position: Vector2(size.x * 0.42, 30),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
    add(statusText);

    // 구역 구분선
    add(RectangleComponent()
      ..size = Vector2(1, size.y)
      ..position = Vector2(size.x * 0.4, 0)
      ..paint = (Paint()..color = Colors.white12));
  }

  void addInventoryItem(String name, double yPos) {
    add(TextComponent(
      text: "[$name]",
      position: Vector2(10, yPos),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.yellowAccent, fontSize: 12)),
    ));
  }

  @override
  void onPanUpdate(dynamic info) {
    final deltaX = info.delta.global.x;
    player.position.x += deltaX;
    player.position.x = player.position.x.clamp(size.x * 0.4, size.x - player.size.x);
    
    for (int i = 0; i < clones.length; i++) {
      double offset = (i == 0) ? -30.0 : 30.0;
      clones[i].position.x = (player.position.x + offset).clamp(size.x * 0.4, size.x - 15);
      clones[i].position.y = player.position.y + 3;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    bossTimer += dt;

    // 아이템 해금 시스템
    if (score >= 1000 && !unlockedMilestones.contains(1000)) {
      unlockedMilestones.add(1000); addInventoryItem("🚀 바주카", 80); laserWidth = 9.0;
    }
    if (score >= 5000 && !unlockedMilestones.contains(5000)) {
      unlockedMilestones.add(5000); addInventoryItem("🚜 탱크", 120); laserWidth = 20.0; shootInterval = 0.09;
    }
    if (score >= 20000 && !unlockedMilestones.contains(20000)) {
      unlockedMilestones.add(20000); addInventoryItem("☢️ 핵미사일", 160); laserWidth = 70.0; shootInterval = 0.06;
    }

    // 좀비 생성: 점수 비례 가속 (최대 0.007초 간격 생성)
    spawnTimer += dt;
    double accel = (score / 50000).clamp(0.0, 1.0);
    double currentInterval = (0.04 - (accel * 0.033)).clamp(0.007, 0.04);
    
    if (spawnTimer > currentInterval) {
      double spawnX = (size.x * 0.41) + (Random().nextDouble() * (size.x * 0.59 - 15));
      add(Zombie(Vector2(spawnX, -15), isBoss: false, bossGen: bossCount));
      spawnTimer = 0;
    }

    // 15초마다 보스
    if (bossTimer >= 15.0) {
      bossCount++;
      double spawnX = (size.x * 0.5) + (Random().nextDouble() * (size.x * 0.4 - 40));
      add(Zombie(Vector2(spawnX, -40), isBoss: true, bossGen: bossCount));
      bossTimer = 0;
    }

    // 분신 추가
    if (gameTime > 10 && clones.length < 1) {
      final c = RectangleComponent()..size = Vector2(15,15)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }
    if (gameTime > 25 && clones.length < 2) {
      final c = RectangleComponent()..size = Vector2(15,15)..paint=(Paint()..color=Colors.cyan.withOpacity(0.5));
      clones.add(c); add(c);
    }

    // 레이저 발사 로직
    shootTimer += dt;
    if (shootTimer > shootInterval) {
      add(Laser(Vector2(player.x + 10 - (laserWidth/2), player.y), laserWidth));
      for (var c in clones) {
        add(Laser(Vector2(c.x + 7 - (laserWidth*0.5/2), c.y), laserWidth * 0.5));
      }
      shootTimer = 0;
    }
    
    // 펜스 파괴 및 투명도 조절
    if (fenceHp <= 0 && fence.parent != null) {
      fence.removeFromParent();
    } else if (fenceHp > 0) {
      fence.paint.color = Colors.orange.withOpacity((fenceHp / 200).clamp(0.1, 0.9));
    }

    int remaining = max(0, 60 - gameTime.toInt());
    statusText.text = 'TIME: ${remaining}s FENCE: ${((fenceHp/200)*100).toInt()}%\nSCORE: $score';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  final bool isBoss;
  int hp;

  Zombie(Vector2 pos, {required this.isBoss, required int bossGen}) 
      : hp = 0,
        super(position: pos, size: isBoss ? Vector2(45, 45) : Vector2(12, 12)) {
    // 좀비 및 보스 체력 강화 (정수 변환)
    hp = isBoss ? (40 + (bossGen * 25)) : (1 + (gameRef.score ~/ 6000).toInt());
    paint = Paint()..color = isBoss ? Colors.purpleAccent : Colors.redAccent;
  }

  @override
  void update(double dt) {
    super.update(dt);
    double speed = isBoss ? 50 : 240 + (gameRef.gameTime * 4);
    y += speed * dt;
    
    // 펜스 충돌 판정
    if (gameRef.fenceHp > 0 && toRect().overlaps(gameRef.fence.toRect())) {
      gameRef.fenceHp -= isBoss ? 30 : 1;
      removeFromParent();
    }

    if (y > gameRef.size.y) removeFromParent();

    gameRef.children.whereType<Laser>().forEach((laser) {
      if (toRect().overlaps(laser.toRect())) {
        hp--;
        laser.removeFromParent(); 
        if (hp <= 0) {
          gameRef.score += isBoss ? 3000 : 50;
          removeFromParent();
        }
      }
    });
  }
}

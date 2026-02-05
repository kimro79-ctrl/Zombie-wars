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
  final List<RectangleComponent> clones = []; // 분신 리스트
  double spawnTimer = 0;
  double shootTimer = 0;
  
  int stage = 1;
  int killsInStage = 0;
  int targetKills = 20; 
  double laserWidth = 6.0;

  late TextComponent statusText;

  @override
  Future<void> onLoad() async {
    // 본체 생성
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

  // 분신 추가 함수
  void addClone(int side) {
    final clone = RectangleComponent()
      ..size = Vector2(30, 30) // 분신은 본체보다 약간 작음
      ..paint = (Paint()..color = Colors.cyan.withOpacity(0.6));
    clones.add(clone);
    add(clone);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    // 본체 이동 (clamped 오타 수정 완료)
    player.position.x += info.delta.global.x;
    player.position.x = player.position.x.clamp(0.0, size.x - player.size.x);
    
    // 분신들이 본체를 따라다니게 함
    for (int i = 0; i < clones.length; i++) {
      double offset = (i % 2 == 0) ? -(60.0 + (i ~/ 2) * 50) : (60.0 + (i ~/ 2) * 50);
      clones[i].position.x = player.position.x + offset;
      clones[i].position.y = player.position.y + 20;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // 10스테이지마다 분신 추가 (최대 4마리)
    int expectedClones = (stage - 1) ~/ 10;
    if (clones.length < expectedClones && clones.length < 4) {
      addClone(clones.length);
    }

    // 스테이지 클리어 로직
    if (killsInStage >= targetKills && stage < 50) {
      stage++;
      killsInStage = 0;
      targetKills += 15; 
      laserWidth = min(40.0, laserWidth + 1.5);
    }

    // 좀비 떼 생성 (하드코어 물량)
    spawnTimer += dt;
    double spawnInterval = max(0.02, 0.22 - (stage * 0.004));
    if (spawnTimer > spawnInterval) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50)));
      spawnTimer = 0;
    }

    // 레이저 발사 (본체 + 분신 모두 발사)
    shootTimer += dt;
    if (shootTimer > 0.15) {
      // 본체 레이저
      add(Laser(Vector2(player.x + 20 - (laserWidth / 2), player.y), laserWidth));
      // 분신 레이저
      for (var clone in clones) {
        add(Laser(Vector2(clone.x + 15 - (laserWidth / 3), clone.y), laserWidth * 0.7));
      }
      shootTimer = 0;
    }
    
    statusText.text = 'STAGE: $stage  LEFT: ${targetKills - killsInStage}  CLONES: ${clones.length}';
  }
}

class Zombie extends RectangleComponent with HasGameRef<ZombieGame> {
  Zombie(Vector2 position) : super(position: position, size: Vector2(40, 40)) {
    paint = Paint()..color = Colors.redAccent;
  }
  @override
  void update(double dt) {
    super.update(dt);
    y += (170 + (gameRef.stage * 6)) * dt;
    if (y > gameRef.size.y) removeFromParent();

    gameRef.children.whereType<Laser>().forEach((laser) {
      if (toRect().overlaps(laser.toRect())) {
        gameRef.killsInStage++;
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

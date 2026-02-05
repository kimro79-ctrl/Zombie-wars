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
    // 에러 수정: clamp를 사용하여 정확한 이동 구현
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
    
    // 난이도 조절: 30초마다 분신 추가 (최대 4마리)
    int expectedClones = (gameTime / 30).floor();
    if (clones.length < expectedClones && clones.length < 4) {
      addClone();
    }

    // 시간 경과에 따른 레이저 위력 증가
    laserWidth = (8.0 + (gameTime / 5)).clamp(8.0, 50.0);

    // 좀비 떼 생성: 2분(120초)에 도달할수록 극한의 난이도로 상승
    spawnTimer += dt;
    double difficultyFactor = (gameTime / 120.0).clamp(0.0, 1.0); 
    double spawnInterval = (0.25 - (difficultyFactor * 0.22)).clamp(0.03, 0.25);
    
    if (spawnTimer > spawnInterval) {
      add(Zombie(Vector2(Random().nextDouble() * (size.x - 40), -50), gameTime));
      spawnTimer = 0;
    }

    // 모든 기체(본체+분신)에서 관통 레이저 발사
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
    statusText.text = 'SURVIVAL: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}  SCORE: $score  CLONES: ${clones.length}';
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
    // 시간이 지날수록 좀비 강하 속도 증가
    double speed = 160 + (gameTimeAtSpawn * 1.2);
    y += speed * dt;
    if (y > gameRef.size.y) removeFromParent();

    // 레이저 충돌 판정 (관통형)
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
    y -= 1100 * dt; // 레이저 속도 상향
    if (y < -50) removeFromParent();
  }
}

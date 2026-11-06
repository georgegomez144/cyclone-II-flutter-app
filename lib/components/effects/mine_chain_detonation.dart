import 'package:flame/components.dart';

class MineChainDetonation extends Component {
  MineChainDetonation({
    required this.count,
    required this.interval,
    required this.onDetonate,
  }) : _isFinished = count == 0 {
    assert(count >= 0);
    assert(interval >= 0);
  }

  final int count;
  final double interval;
  final void Function(int index) onDetonate;

  double _elapsed = 0;
  int _detonatedCount = 0;
  bool _isFinished;

  int get detonatedCount => _detonatedCount;
  bool get isFinished => _isFinished;

  @override
  void update(double dt) {
    super.update(dt);
    if (dt < 0 || _isFinished) return;

    _elapsed += dt;
    while (_detonatedCount < count && _elapsed >= _detonatedCount * interval) {
      final index = _detonatedCount++;
      onDetonate(index);
    }

    if (_detonatedCount == count) {
      _isFinished = true;
      if (isMounted) removeFromParent();
    }
  }
}

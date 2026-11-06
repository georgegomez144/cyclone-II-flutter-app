class BonusTally {
  BonusTally({required this.total, required this.duration}) {
    if (total < 0) {
      throw ArgumentError.value(total, 'total', 'Must not be negative');
    }
    if (!duration.isFinite || duration <= 0) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive');
    }
  }

  final int total;
  final double duration;
  double _elapsed = 0;
  int _transferred = 0;

  int get remaining => total - _transferred;

  bool get isDone => remaining == 0;

  int step(double dt) {
    if (isDone || dt <= 0 || !dt.isFinite) return 0;

    final timeRemaining = duration - _elapsed;
    _elapsed = dt >= timeRemaining - duration * 1e-12
        ? duration
        : _elapsed + dt;
    final targetTransferred = _elapsed >= duration
        ? total
        : (total * _elapsed / duration).floor();
    final points = targetTransferred - _transferred;
    _transferred = targetTransferred;
    return points;
  }

  int finish() {
    final points = remaining;
    _transferred = total;
    _elapsed = duration;
    return points;
  }
}

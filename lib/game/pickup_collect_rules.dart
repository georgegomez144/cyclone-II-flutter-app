import 'package:flame/components.dart';

class PickupCollectRules {
  static double shipCollectDistance(double playerSize, double pickupSize) =>
      playerSize / 2 + pickupSize / 2;

  static bool canShipCollect(
    Vector2 playerPosition,
    Vector2 pickupPosition,
    double playerSize,
    double pickupSize,
  ) =>
      playerPosition.distanceTo(pickupPosition) <=
      shipCollectDistance(playerSize, pickupSize);
}

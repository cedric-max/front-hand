class GyroscopeData {
  final double x;

  final double y;

  final double z;

  GyroscopeData({required this.x, required this.y, required this.z});

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
    };
  }
}

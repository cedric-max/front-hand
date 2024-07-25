class GyroscopeData {
  final double x;
  final double y;
  final double z;

  GyroscopeData({required this.x, required this.y, required this.z});

  @override
  String toString() {
    return 'GyroscopeData(x: $x, y: $y, z: $z)';
  }
}

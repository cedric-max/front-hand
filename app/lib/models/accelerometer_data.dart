class AccelerometerData {
  final double x;
  final double y;
  final double z;

  AccelerometerData({required this.x, required this.y, required this.z});

  @override
  String toString() {
    return 'AccelerometerData(x: $x, y: $y, z: $z)';
  }
}

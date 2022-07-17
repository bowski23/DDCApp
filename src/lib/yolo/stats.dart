/// Bundles different elapsed times
class Stats {
  /// Total time taken in the isolate where the inference runs
  int? totalPredictTime;

  /// [totalPredictTime] + communication overhead time
  /// between main isolate and another isolate
  int? totalElapsedTime;

  /// Time for which inference runs
  int? inferenceTime;

  /// Time taken to pre-process the image
  int? preProcessingTime;

  int? height;
  int? width;

  Stats(
      {this.totalPredictTime,
      this.totalElapsedTime,
      this.inferenceTime,
      this.preProcessingTime,
      this.height,
      this.width});

  @override
  String toString() {
    return 'Stats{totalPredictTime: $totalPredictTime, totalElapsedTime: $totalElapsedTime, inferenceTime: $inferenceTime, preProcessingTime: $preProcessingTime}';
  }
}

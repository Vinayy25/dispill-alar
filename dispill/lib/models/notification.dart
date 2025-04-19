class Notifications {
  final String tabletName;
  final String takeTime;
  final String takeDuration;
  final String period;
  final bool missed;
  final bool afterFood;
  final double dosage;

  Notifications(
    this.tabletName,
    this.takeTime,
    this.takeDuration,
    this.missed,
    this.afterFood,
    this.period,
    this.dosage,
  );
}

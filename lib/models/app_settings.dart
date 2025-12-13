/// 应用设置模型
class AppSettings {
  final bool onboardingCompleted;
  final bool selfBirthdaySet;
  final int themeModeIndex;
  final int seedColorValue;

  const AppSettings({
    this.onboardingCompleted = false,
    this.selfBirthdaySet = false,
    this.themeModeIndex = 0,
    this.seedColorValue = 0xFF2196F3, // Colors.blue
  });

  AppSettings copyWith({
    bool? onboardingCompleted,
    bool? selfBirthdaySet,
    int? themeModeIndex,
    int? seedColorValue,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      selfBirthdaySet: selfBirthdaySet ?? this.selfBirthdaySet,
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      seedColorValue: seedColorValue ?? this.seedColorValue,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      selfBirthdaySet: json['selfBirthdaySet'] as bool? ?? false,
      themeModeIndex: json['themeModeIndex'] as int? ?? 0,
      seedColorValue: json['seedColorValue'] as int? ?? 0xFF2196F3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'onboardingCompleted': onboardingCompleted,
      'selfBirthdaySet': selfBirthdaySet,
      'themeModeIndex': themeModeIndex,
      'seedColorValue': seedColorValue,
    };
  }
}

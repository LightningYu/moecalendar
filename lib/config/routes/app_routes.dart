/// 应用路由常量
class AppRoutes {
  AppRoutes._();

  // ============ 主要路由 ============
  static const String onboarding = '/onboarding';
  static const String birthTab = '/birth';
  static const String characterTab = '/character';
  static const String taskPoolTab = '/task_pool';

  // ============ 子路由（相对路径） ============
  static const String detail = 'detail';
  static const String addManual = 'add_manual';
  static const String addBangumi = 'add_bangumi';
  static const String addSelf = 'add_self';
  static const String editSelf = 'edit_self';

  // ============ 完整路径 ============
  static const String birthDetailPath = '$birthTab/$detail';
  static const String birthGridPath = '$birthTab/grid';
  static const String characterDetailPath = '$characterTab/$detail';
  static const String addManualPath = '$characterTab/$addManual';
  static const String addBangumiPath = '$characterTab/$addBangumi';
  static const String addSelfPath = '$characterTab/$addSelf';
  static const String editSelfPath = '$characterTab/$editSelf';

  // ============ 庆祝页面 ============
  static const String congratulate = '/congratulate';
  static const String congratulateSelf = '/congratulate/self';
  static const String congratulateCharacter = '/congratulate/character';

  // ============ 设置页面 ============
  static const String settings = '/settings';
  static const String settingsBangumi = 'bangumi';
  static const String settingsBangumiPath = '$settings/$settingsBangumi';
  static const String profile = 'profile';
  static const String profilePath = '$settings/$profile';
  static const String about = 'about';
  static const String aboutPath = '$settings/$about';
  static const String dataSync = 'data_sync';
  static const String dataSyncPath = '$settings/$dataSync';
}

/// 设计系统常量
/// 定义应用中使用的标准间距、圆角、阴影等视觉元素
class DesignConstants {
  // 私有构造函数，防止实例化
  DesignConstants._();

  // ============ 间距 (Spacing) ============
  /// 极小间距 - 用于紧密元素之间
  static const double spacingXs = 4.0;

  /// 小间距 - 用于同一组内的元素
  static const double spacingSm = 8.0;

  /// 中等间距 - 用于不同组之间
  static const double spacingMd = 12.0;

  /// 标准间距 - 最常用的间距
  static const double spacing = 16.0;

  /// 大间距 - 用于分隔不同区域
  static const double spacingLg = 24.0;

  /// 超大间距 - 用于重要分隔
  static const double spacingXl = 32.0;

  // ============ 圆角 (Border Radius) ============
  /// 小圆角 - 用于 tags、chips
  static const double radiusSm = 6.0;

  /// 中等圆角 - 用于卡片、按钮
  static const double radiusMd = 12.0;

  /// 大圆角 - 用于特殊卡片
  static const double radiusLg = 16.0;

  /// 完全圆形
  static const double radiusCircle = 999.0;

  // ============ 阴影 (Elevation) ============
  /// 无阴影
  static const double elevationNone = 0.0;

  /// 小阴影
  static const double elevationSm = 1.0;

  /// 中等阴影
  static const double elevationMd = 2.0;

  /// 大阴影
  static const double elevationLg = 4.0;

  // ============ 尺寸 (Sizes) ============
  /// 头像尺寸 - 小
  static const double avatarSizeSm = 64.0;

  /// 头像尺寸 - 中
  static const double avatarSizeMd = 72.0;

  /// 头像尺寸 - 大
  static const double avatarSizeLg = 80.0;

  /// 图标尺寸 - 小
  static const double iconSizeSm = 12.0;

  /// 图标尺寸 - 中
  static const double iconSizeMd = 16.0;

  /// 图标尺寸 - 大
  static const double iconSizeLg = 24.0;

  // ============ Tag/Chip 样式 ============
  /// Tag 水平内边距
  static const double tagPaddingH = 8.0;

  /// Tag 垂直内边距
  static const double tagPaddingV = 4.0;

  /// Tag 圆角
  static const double tagRadius = radiusSm;

  /// Tag 字体大小
  static const double tagFontSize = 11.0;

  // ============ 卡片样式 ============
  // 注意: 卡片相关常量引用基础间距值以保持一致性
  // 这样可以在修改基础值时自动更新卡片样式
  
  /// 卡片水平外边距
  static const double cardMarginH = spacing;

  /// 卡片垂直外边距
  static const double cardMarginV = spacingSm;

  /// 卡片内边距
  static const double cardPadding = spacingMd;

  /// 卡片圆角
  static const double cardRadius = radiusMd;

  // ============ 列表样式 ============
  /// 列表项垂直内边距
  static const double listItemPaddingV = spacingMd;

  /// 列表项水平内边距
  static const double listItemPaddingH = spacing;

  /// 列表底部留白（避免被 FAB 遮挡）
  static const double listBottomPadding = 100.0;
}

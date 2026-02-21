# 萌历 (MoeCalendar)

<p align="center">
  <a href="https://github.com/LightningYu/moecalendar">
    <img src="assets/img/ico.webp" alt="Logo" width="100" height="100">
  </a>

  <h3 align="center">萌历-MoeCalendar</h3>
  <p align="center">
    萌历是一款专为二次元爱好者打造的角色生日提醒应用。通过集成 Bangumi 数据，让你不再错过心爱角色的每一个重要时刻.
    <br />
    <a href=""><strong>探索本项目的文档 »</strong></a>
    <br />
    <br />
    <a href="https://github.com/LightningYu/moecalendar">查看Demo</a>
    ·
    <a href="https://github.com/LightningYu/moecalendar/issues">报告Bug</a>
    ·
    <a href="https://github.com/LightningYu/moecalendar/issues">提出新特性</a>
  </p>
</p>

[<img alt="Dynamic JSON Badge" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.bilibili.com%2Fx%2Frelation%2Fstat%3Fvmid%3D1938216007&query=data.follower&style=for-the-badge&logo=bilibili&label=bilibili%3A%E9%9B%B7%E9%9C%86%E5%AE%87%E5%AE%87%E4%BE%A0&labelColor=%23ffc1cc&color=%23d1e0f0&link=https%3A%2F%2Fspace.bilibili.com%2F1938216007">](https://space.bilibili.com/1938216007)
[<img alt="GitHub Release" src="https://img.shields.io/github/v/release/lightningyu/moecalendar?sort=semver&display_name=tag&style=for-the-badge&label=Download">](https://github.com/LightningYu/moecalendar/releases)


## ✨ 功能特性

- **角色生日追踪**:支持从 Bangumi 导入角色，自动同步生日信息.
- **日历同步**:支持将角色生日一键同步至系统日历，利用系统能力实现精准提醒.
- **图标**:由作者亲手绘制
- **数据导出导入**:支持json文件或者剪切板导出入数据
## 🚀 快速开始

### 环境要求
- **Flutter SDK**: `>= 3.9.2`
- **Java**: `JDK 17` (用于 Android 构建)
- **Android SDK**: `API 35`

### 本地开发环境搭建

1. **克隆项目**
   ```bash
   git clone https://github.com/LightningYu/moecalendar.git
   cd moecalendar
   ```

2. **配置环境变量 (`.env`)**
   在项目根目录创建 `.env` 文件，填入你的 Bangumi API 密钥,没有就去注册[[Bangumi开发者](https://bangumi.tv/dev/app)]:
   ```dart
   BANGUMI_APP_ID= 填自己的
   BANGUMI_APP_SECRET= 自己去注册
   ```

3. **配置安卓签名 (可选)**
   如果你需要进行 Release 签名打包
   在android/app下打开命令行，输入
    ``` pwsh
    keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
   ```
   请在 [android/app/](android/app) 下创建 `key.properties`:
   ```properties
   storePassword=你的密码
   keyPassword=你的密码
   keyAlias=key
   storeFile=key.jks
   ```
   PS:`keyAlias`和`storeFile`最好别改

4. **运行**
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=.env
   ```
   或者直接在vscode里面`ctrl`+`shift`+`p`开task,我写有

## 📦 自动化构建 (GitHub Actions)

项目已配置 GitHub Actions，推送以 `v` 开头的 Tag（如 `v1.0.0`）即可触发自动打包.
### GitHub Secrets 配置
在仓库 `Settings > Secrets` 中配置以下项:
- `ENV_FILE`: 完整的 `.env` 文件内容.
- `KEY_STORE`: `key.jks` 文件的 Base64 编码.
    - 可用powershell
        ```pwsh
        [Convert]::ToBase64String([IO.File]::ReadAllBytes("key.jks")) | Out-File -FilePath "key_base64.txt" -Encoding utf8
        ```    
- `KEY_PROPERTIES`: `key.properties` 文件的完整内容.

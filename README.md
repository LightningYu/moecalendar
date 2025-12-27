# 萌历 (MoeCalendar) 📅

萌历是一款专为二次元爱好者打造的角色生日提醒应用。通过集成 Bangumi 数据，让你不再错过心爱角色的每一个重要时刻.
## ✨ 功能特性

- **角色生日追踪**:支持从 Bangumi 导入角色，自动同步生日信息.- **日历同步**:支持将角色生日一键同步至系统日历，利用系统能力实现精准提醒.- **精美 UI**:基于 Flutter 构建，支持动态主题色与丝滑动画.- **隐私安全**:所有数据本地存储，敏感密钥通过环境变量注入.
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
   在项目根目录创建 `.env` 文件，填入你的 Bangumi API 密钥:
   ```dart
   BANGUMI_APP_ID=bgm5232693cf5bc89849
   BANGUMI_APP_SECRET=你的_SECRET
   ```

3. **配置安卓签名 (可选)**
   如果你需要进行 Release 签名打包
   在android/app下打开命令行，输入
    ``` pwsh
    keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
   ```
   请在 `android/app/` 下创建 `key.properties`:
   ```properties
   storePassword=你的密码
   keyPassword=你的密码
   keyAlias=key
   storeFile=key.jks
   ```

4. **运行**
   ```bash
   flutter pub get
   ```

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

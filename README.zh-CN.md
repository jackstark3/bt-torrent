# BT 种子搜索器

[English README](README.md)

基于 Flutter 开发的 Android 种子搜索与下载应用。多源聚合搜索、原生 BT 引擎下载、本地视频播放，全部在设备端完成，无需后端服务器。

> ⚠️ **法律声明**：本项目仅供学习与个人使用，请遵守您所在地区的版权法律及各站点服务条款。

## 功能特性

- **多源并行搜索** — 同时聚合 1337x（经 1377x 镜像）、The Pirate Bay（经镜像）、SolidTorrents、TorrentGalaxy，以及任意 Torznab 索引器（Jackett / Prowlarr）
- **搜索体验** — 结果渐进加载、分类与排序筛选、搜索历史自动补全、离线缓存回退、按源健康检查与启用/禁用
- **原生 BT 引擎** — libtorrent4j（libtorrent 2.x），经 Pigeon 桥接；开启 DHT/LSD、磁力元数据获取、实时进度推送
- **后台下载** — 前台服务保活，App 退到后台下载不中断
- **任务持久化** — 重启 App 任务不丢，未完成任务自动续传
- **文件导出** — 下载完成自动导出到手机公共"下载"目录
- **本地视频播放** — 全屏播放器（播放/暂停、进度拖拽）
- **网络代理支持** — 设置页可配置 HTTP 代理，适配受限网络
- **Torznab 对接** — 可配置自建 Jackett / Prowlarr 实例

## 技术栈

| 分层 | 技术 |
|---|---|
| UI / 逻辑 | Flutter (Dart) + Riverpod + go_router |
| 原生引擎 | libtorrent4j 2.1.0-36 |
| 桥接 | Pigeon（类型安全平台通道） |
| 网络 | dio + HTML/XML 解析 |
| 存储 | SharedPreferences + JSON 文件 |
| 播放器 | video_player（Media3/ExoPlayer） |
| 后台 | Android 前台服务 |

## 构建

环境要求：Flutter 3.x、Android SDK、JDK 17。

```bash
flutter pub get
flutter build apk --debug   # 调试包
flutter build apk --release # 发布包
```

国内网络注意事项：

- Gradle 发行版下载已配置腾讯镜像（`android/gradle/wrapper/gradle-wrapper.properties`）
- Maven 依赖已配置阿里云镜像（`android/settings.gradle.kts`、`android/build.gradle.kts`）
- 若 C 盘空间不足，可将 Gradle 缓存指向其他盘：

```powershell
$env:GRADLE_USER_HOME = "D:\gradle_home"
$env:TMP = "D:\tmp"; $env:TEMP = "D:\tmp"
flutter build apk --debug
```

调试包包含 3 种 CPU 架构的原生库（约 200MB）。发布版建议按 ABI 拆分以减小体积。

## 使用说明

1. **搜索** — 输入关键词（或粘贴磁力链接）。各搜索源结果到达后逐个显示。
2. **下载** — 点击结果卡片上的下载按钮。引擎先获取元数据，再实时显示下载进度。
3. **播放** — 下载完成后进入任务详情，点**播放**。文件也会导出到手机"下载"目录。
4. **设置** — 可启用/禁用搜索源、配置网络代理、设置 Torznab 索引器。

## 项目结构

```
lib/
├── core/        # 数据模型、工具、常量
├── domain/      # 仓库接口与用例
├── data/        # 仓库实现、本地存储、搜索源
├── engine/      # Dart 端 BT 引擎门面 + Pigeon 桥接
├── features/    # 搜索 / 下载 / 播放 / 设置 页面
└── providers/   # Riverpod providers
android/
└── app/src/main/kotlin/com/bt/
    ├── engine/  # libtorrent4j 会话与 torrent handle 封装
    ├── bridge/  # Pigeon API 实现
    └── service/ # 前台下载服务
pigeons/         # Pigeon 接口定义
```

## 开发路线

- [x] 多源搜索
- [x] 原生下载引擎
- [x] 已完成文件本地播放
- [ ] 边下边播（渐进式流播）
- [ ] DHT 去中心化搜索
- [ ] 发布版构建（ABI 拆分）

## 免责声明

本软件仅用于学习交流。使用者需自行确保其使用行为符合所在地法律法规。

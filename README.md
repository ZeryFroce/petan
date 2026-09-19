# 宠安 PetAn 🐾

一款**离线优先**的宠物健康管理 App（Android）。数据 100% 存储在本机，无需注册账号、无需联网也能完整使用；可选 WebDAV 同步实现家庭成员共享。

> 为养宠人打造的私人宠物档案：健康记录、体重趋势、可自定义的健康评分、用品柜库存管理、消费统计与身价、相册回忆墙、到期提醒。

## ✨ 功能特性

- **🐾 多宠物档案**：猫/狗档案，品种选择、年龄换算（人类年龄）、头像、绝育/性别信息
- **📋 健康记录**：疫苗、驱虫、体检、生病、用药、喂食、清洁护理等类型，支持费用与附件
- **🩺 可自定义健康评分**：10 分制加减分规则引擎，主人自由编辑加减分项、分值与统计周期（周期打卡型 / 按次计分型），内置体检、清洁、常见病症等建议值模板
- **⚖️ 体重趋势**：折线图 + 最高/最低/平均/累计变化统计
- **📦 用品柜**：药品、猫砂、零食等消耗品库存管理，入库（金额/渠道/生产日期/保质期）与消耗流水，记录健康动态时可关联消耗并自动扣减库存
- **💰 消费与身价**：为它花的每一笔都计入「宠物身价」，月/年消费分类图表，大件装备展示
- **📷 相册与回忆墙**：每日打卡照片（最多 9 张，可选压缩），定期生成回忆
- **⏰ 到期提醒**：疫苗/驱虫/复查等系统通知提醒
- **🔒 隐私与安全**：PIN 码 + 指纹/面容解锁
- **☁️ WebDAV 同步**：可选自动/手动同步，家庭成员共享数据（按 id 合并，本地优先）

## 📥 下载安装

前往 [**Releases**](../../releases) 页面下载最新版 `app_vX.XX.apk`，安装即可。

- 系统要求：Android 7.0（API 24）及以上
- 数据保存在应用私有目录，卸载即清除，建议定期使用「我的 → 数据管理」导出备份

## 🚀 本地构建

```bash
# 环境要求：Flutter 3.x、JDK 17、Android SDK（compileSdk 36）
flutter pub get
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

或使用版本化构建脚本（自增版本号 + 归档 APK + 追加 CHANGELOG）：

```bash
bash build_release.sh "本次更新说明"
```

## 🔄 自动发布（GitHub Actions）

推送到远端后，打 tag 即可自动构建并发布 Release：

```bash
git tag v1.12 && git push origin v1.12
# Actions 自动完成：flutter build apk → 挂载到 GitHub Release
```

工作流定义见 [.github/workflows/release.yml](.github/workflows/release.yml)。

## 🛠 技术栈

Flutter (Material 3) · sqflite（本地存储）· fl_chart（图表）· flutter_local_notifications（提醒）· local_auth（生物识别）· webdav_client（同步）· image / image_picker / photo_view（相册）

## 📂 项目结构

```
lib/
├── main.dart            # 入口与锁屏
├── shell.dart           # 底部四 Tab 骨架（首页/提醒/健康/我的）
├── theme.dart           # 设计系统（颜色/圆角/间距/字体 token）
├── database.dart        # sqflite 数据层（schema v6，含迁移）
├── models.dart          # 数据模型 + 健康评分规则引擎
├── home_page.dart       # 首页：待办/宠物/用品柜/动态概览
├── health_page.dart     # 健康：规则化评分 + 规则管理 + 体重趋势
├── supplies_page.dart   # 用品柜：库存/入库/消耗/流水
├── pet_detail_page.dart # 宠物详情：档案/记录/体重/相册/消费
└── widgets/             # 公共组件与底部面板
```

## 📝 更新日志

见 [CHANGELOG.md](CHANGELOG.md)。

## 📄 许可证

[MIT](LICENSE)

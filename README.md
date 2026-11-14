# NoFap

iPhone 上的持续计时。从开始的那一秒算起，精确到秒。确认重新开始后归零，上一轮记入轨迹。

天数按每满 24 小时计算，不受午夜和时区切换影响。锁屏、退出或重启后，用保存的开始时间重算，不靠每秒累加。记录只在这台手机上。

这是计时工具，不提供医疗或健康效果承诺，也没有每日打卡。

界面是黑底、冷银色数字和少量红色刻度。主按钮是「重新开始」。

天数使用随 App 打包的 Six Caps 字体（SIL Open Font License，见 `NoFap/Fonts/OFL.txt`），无需联网加载。三个页面共用固定的底部导航，内容可独立滚动。

## 开发

工程由 `project.yml` 经 XcodeGen 生成。最低系统 iOS 17，用 Xcode 26 和 iOS 26 SDK 编译上传。

```bash
xcodegen generate
xcodebuild test -project NoFap.xcodeproj -scheme NoFap -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

发布步骤见 `RELEASE.md`。

# ytpodcast

极简 YouTube 精听学习工具 MVP。

## 已实现

- 添加 YouTube 链接并解析真实 `videoId`
- 使用 `https://img.youtube.com/vi/{videoId}/hqdefault.jpg` 生成封面
- 本地保存视频列表、字幕理解状态、生词本
- 首页展示视频合集、封面、标题、理解进度
- 学习页暂时显示完整移动端 YouTube 网页
- 字幕区域预留，后续接入 FastAPI transcript 服务
- 字幕按播放时间高亮并自动滚动
- 点击字幕可跳转播放时间
- `不懂` 会暂停并标记当前字幕
- `懂了` 会标记当前字幕并跳到下一句继续播放
- 字幕单词可点击查词并加入/取消生词本
- 生词本可查看来源并取消收藏

## 技术栈

- Flutter / Dart
- `webview_flutter`
- `shared_preferences`
- `provider`
- `uuid`

## 运行

```bash
flutter pub get
flutter run
```

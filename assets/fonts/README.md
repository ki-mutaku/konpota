# 日本語フォント

`NotoSansJP-Regular.otf` を `project.godot` の `gui/theme/custom_font` に指定する。
Web版はOSの日本語フォントで補完できないため、フォントをゲームに同梱する。

- フォント: Noto Sans JP Regular
- 配布元: https://github.com/notofonts/noto-cjk
- 元ファイル: https://github.com/notofonts/noto-cjk/blob/main/Sans/SubsetOTF/JP/NotoSansJP-Regular.otf
- Copyright 2014-2021 Adobe (http://www.adobe.com/).
- Noto is a trademark of Google Inc.
- ライセンス: SIL Open Font License 1.1（同梱の `OFL.txt`）

画像とフォントはGit LFSの管理対象。CIのcheckoutには `lfs: true` が必要。
インポート後、以下で画像データとUIフォントの日本語グリフを確認できる。

```sh
godot --headless --path . --import --quit
godot --headless --path . --script tests/web_assets_smoke.gd
```

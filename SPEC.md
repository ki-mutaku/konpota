# コンポタマスター SPEC

## 1. 目的

本ドキュメントは、2D料理シミュレーションゲーム「コンポタマスター」をGodotで3人チーム開発するための実装仕様・開発ルールを定義する。

- Scene構成を統一し、`.tscn` の競合を減らす
- 各メンバーの担当範囲を明確にする
- SceneとGDScriptの責務を分離する
- Git/GitHubによる並行開発を安全に行う
- AI Coding Agentが既存設計を壊さず実装できる基準を用意する

## 2. ゲーム概要

プレイヤーが2Dのキッチンで材料や調理器具を操作し、コンポタを作って客に提供する料理シミュレーションゲーム。

材料・調理方法によってコンポタの「甘さ・コク・食感」が変化する。客の要望に合わせながら、制限時間内に満足度ノルマの達成を目指す。

中心となる体験：

- 自分の操作でコンポタを調理する
- 材料や調理方法を試してレシピを発見する
- 客の好みに合わせたコンポタを提供する
- 品質と調理速度のバランスを考える
- 制限時間内に満足度ノルマを達成する

## 3. 基本ゲームループ

``` text
Title
 ↓
StageStart
 ↓
Kitchen
 ↓
調理 → 提供 → 評価・満足度加算
 ↑                    ↓
 └──── 制限時間まで ──┘
 ↓
Result
 ↓
クリア → 成長・アンロック → 次ステージ
失敗   → 再挑戦
```

全3ステージを想定する。

## 4. 技術方針

- Engine: Godot 4.x
- Game Type: 2D
- Language: GDScript
- Version Control: Git
- Remote Repository: GitHub
- Primary Input: タッチ / スワイプ / ドラッグ
- Keyboard Input: 原則として実装しない

Scene
Editorを使用し、Sprite、CollisionShape2D、Area2D、UI、Animation、調理器具や材料の配置を視覚的に編集する。ゲームロジックは可能な限りGDScriptへ分離する。

巨大な `kitchen.tscn`
に全Nodeを直接作成せず、Player、調理器具、材料、Customer、UIなどを独立Sceneとして構成する。

## 5. ディレクトリ構成

``` text
res://
├── scenes/
│   ├── game/
│   │   ├── title.tscn
│   │   ├── stage_start.tscn
│   │   ├── kitchen.tscn
│   │   └── result.tscn
│   ├── player/
│   │   └── player.tscn
│   ├── cooking/
│   │   ├── pot.tscn
│   │   ├── stove.tscn
│   │   ├── mixer.tscn
│   │   ├── ladle.tscn
│   │   └── serving_counter.tscn
│   ├── ingredients/
│   │   └── ingredient.tscn
│   ├── customers/
│   │   └── customer.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── customer_order.tscn
│       └── evaluation.tscn
├── scripts/
│   ├── game/
│   ├── player/
│   ├── cooking/
│   ├── ingredients/
│   ├── customers/
│   └── ui/
├── resources/
│   ├── ingredients/
│   ├── recipes/
│   ├── customers/
│   └── stages/
├── assets/
│   ├── sprites/
│   ├── ui/
│   ├── audio/
│   └── fonts/
├── project.godot
└── SPEC.md
```

大きな構造変更はチームで共有してから行う。

## 6. Scene Architecture

### 6.1 Kitchen

``` text
Kitchen (Node2D)
├── Background
├── KitchenObjects
│   ├── Stove
│   ├── Pot
│   ├── Mixer
│   ├── Ladle
│   └── ServingCounter
├── Ingredients
├── Customers
├── Player
└── UI
	└── HUD
```

Kitchenの責務：

- ステージ開始・終了
- 制限時間管理
- 累計満足度管理
- Customer生成
- Resultへの遷移
- 各Sceneの統合

### 6.2 Player

``` text
Player (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
└── InteractionArea (Area2D)
	└── CollisionShape2D
```

責務：

- 2D移動
- 周辺オブジェクト検出
- 材料・器具とのインタラクション
- アイテムを持つ・置く

### 6.3 Pot

責務：

- 投入された材料の保持
- コンポタのパラメータ管理
- 加熱状態管理
- 混ぜた状態の管理
- 調理成功・失敗判定
- 完成したSoupデータの生成

### 6.4 Ingredient

材料は最低限以下のデータを持つ。

``` text
id
display_name
sweetness
richness
texture
```

材料ごとの差は可能な限り個別ScriptではなくResourceとして定義する。

### 6.5 Customer

責務：

- 客の好み・要望を保持
- コンポタを受け取る
- 評価処理へSoupを渡す
- 評価結果をゲーム進行へ通知する

### 6.6 HUD

表示内容：

- 残り時間
- 累計満足度
- 目標満足度
- 現在の客
- 客の要望

ゲームロジックそのものはHUDに持たせない。

## 7. SceneとScriptの責務分離

原則として以下のように分ける。

``` text
scenes/cooking/pot.tscn
scripts/cooking/pot.gd
```

`.tscn`：

- Node構造
- Sprite
- Collision
- Node位置
- Inspector設定
- Animation
- Signal接続

`.gd`：

- 状態管理
- 計算
- 入力処理
- 調理ロジック
- 満足度計算
- Scene間通信

## 8. 操作・調理仕様

本ゲームはタッチ、スワイプ、ドラッグ操作を基本とし、キーボード操作は原則として作らない。

想定する調理工程：

- 鍋のスープを混ぜる
- ミキサーでコーンをすりつぶす
- 牛乳を注ぎ入れる
- 砂糖などの材料を投入する
- コンロで加熱する

具体的な操作：

### 加熱

コンロのツマミをスワイプ／ドラッグして操作する。操作量に応じて火力を変更できる方式を想定する。

### 混ぜる

お玉をプレイヤー自身がスワイプ／ドラッグして鍋の中を混ぜる。

### ミキサー

コーンをミキサーへ入れ、操作することですりつぶす。具体的なジェスチャー・成功条件は今後決定する。

### 材料投入

牛乳を注ぐ、砂糖を入れるなど、材料に応じた操作を行う。材料量を連続量として扱うか段階式にするかは未確定。

## 9. コンポタ評価

コンポタは以下の3軸で評価する。

| Parameter | 内容             |
|-----------|------------------|
| sweetness | 甘さ             |
| richness  | コク             |
| texture   | 食感・なめらかさ |

プレイヤーへの評価表示は各項目 **☆5満点** とする。

内部計算で使用する数値範囲と☆への変換方法は未確定。

## 10. 客・満足度システム

客は「甘いのがいい」「コクがあるのが好き」など、ざっくりとした要望を提示する。

完成したコンポタと客の要望を比較して満足度を算出する。満足度の具体的な計算式は未確定。

提供ごとに満足度を累積し、ステージのクリア判定に使用する。

## 11. 調理成功・失敗

調理には成功・失敗の概念を設ける。

調理に失敗した場合、完成したコンポタの全ステータスを半減させる。

``` text
sweetness = sweetness * 0.5
richness  = richness  * 0.5
texture   = texture   * 0.5
```

失敗判定の条件・タイミング・端数処理は未確定。

「調理技術」のレベルが高いほど、調理器具を使用した際の調理成功率が上昇する。

## 12. レシピシステム

特定の材料・量・調理条件を満たした場合、新しいレシピとして扱う。

``` text
recipe_id
display_name
required_ingredients
conditions
```

レシピ発見条件は未確定。

「ひらめき」のレベルによって、新しいレシピのヒントが提示される確率が上昇する。

## 13. 材料システム

具体的な材料一覧と各材料のパラメータは今後決定する。

一度獲得・アンロックした材料を無制限に使用できる方式を候補とするが、現時点では未確定。

## 14. ステージ仕様

全3ステージとする。

制限時間は各ステージ **5〜10分程度**
を候補とし、プレイテストを踏まえて確定する。

Stage 1の満足度ノルマは **30点程度**
を候補とし、後半ステージほどノルマを上げる。

ステージが進むにつれて登場する客を増やす。

### Stage 1：近所の空き地

客の例：

- 買い物帰りのおばさん
- 野球少年

基本操作と基本的なコンポタ作りを学ぶステージ。

### Stage 2：キッチンカー

客の例：

- 女子高生
- 会社帰りの会社員

客の種類を増やし、異なる好みへの対応を要求する。

### Stage 3：レストラン

客の例：

- お金持ちのマダム
- コンポタ奉行

複雑な要望を持つ客が登場する。最終ボスとして「コンポタ奉行」を配置する。

### ボス

各ステージにボス客を設定する。

ボスを満足させると通常客より多くの満足度報酬を獲得できる。

ボスの出現条件、要求、報酬倍率は未確定。

### クリア条件

``` text
total_satisfaction >= target_satisfaction
```

制限時間終了時に条件を満たしていなければ失敗。再挑戦可能とする。

## 15. 料理レベル・成長システム

プレイヤーは以下の4能力を成長させられる。

| 能力       | 効果                                                   |
|------------|--------------------------------------------------------|
| 調理技術   | Lvが上がるごとに、調理器具での調理成功率が上がる       |
| ひらめき   | Lvが上がるごとに、新しいレシピのヒント提示確率が上がる |
| 味覚       | Lvが上がるごとに、客の要望がより分かりやすくなる       |
| コンポタ愛 | スープステータスにボーナスが付き、満足度報酬も増える   |

レベル上限、レベルアップ条件、各レベルの具体的効果量は未確定。

## 16. UI仕様

### Title

- Game Start
- Exit

### Stage Start

- ステージ名
- 制限時間
- 目標満足度
- 使用可能材料

### HUD

- 残り時間
- 累計満足度
- 目標満足度
- 客の情報
- 客の要望

### Evaluation

- 甘さ：☆1〜5
- コク：☆1〜5
- 食感：☆1〜5
- 獲得満足度
- 調理成功／失敗

### Result

- 累計満足度
- 提供数
- 発見したレシピ
- Clear / Failed

## 17. チーム開発方針

最重要ルール：

> 同じ `.tscn` を複数人が同時に編集しない。

`.tscn` はテキスト形式だが、Scene
Editorによる変更は差分が複雑になる場合があるため、手動マージを常態化させない。

各メンバーのScene Ownershipは未確定。話し合い後に本SPECへ追記する。

`kitchen.tscn`
は各Sceneを統合するため競合しやすいので、原則として統合担当者を1人決める。

## 18. Git Workflow

`main` へ直接実装をpushしない。

``` text
main
 ├── feature/player
 ├── feature/cooking
 └── feature/ui
```

基本フロー：

``` bash
git switch main
git pull
git switch -c feature/<feature-name>
```

``` text
feature branch
	  ↓
Push
	  ↓
Pull Request
	  ↓
Review / 動作確認
	  ↓
main
```

PRは可能な限り小さい単位にする。

## 19. Scene間通信

Scene間の依存を減らすため、必要に応じてSignalを使用する。

``` text
Customer
   │ soup_served
   ↓
GameManager
   │
   ├── Satisfaction更新
   └── HUDへ通知
```

PlayerがHUD内部Nodeを直接操作するような強い依存は避ける。

## 20. AI Coding Agent利用方針

Codex等のAI Coding Agentを利用してよい。

AIには実装前に `SPEC.md` を参照させる。

``` text
SPEC.mdを読んでから実装してください。

既存のScene Architectureとディレクトリ構造を尊重してください。
担当外のSceneを理由なく変更しないでください。
未確定仕様を推測で確定させないでください。
既存仕様を変更する必要がある場合は、勝手に変更せず理由を示してください。
```

AIによる `.tscn` の生成・編集は禁止しない。ただしGodot
Editorで開き、動作確認してからcommitする。

## 21. PR前の完了条件

- Godot Editorでエラーなく開ける
- 実行時エラーが発生しない
- 担当外Sceneへの不要な変更がない
- 新規Sceneを単体で確認できる
- 必要なResource・ScriptがGit管理されている
- SPECと実装が矛盾していない
- 仕様変更時は必要に応じて `SPEC.md` も更新する

## 22. 未確定仕様

以下は未確定とし、チームでの話し合い・AIとの壁打ち・プレイテストを通して決定する。

1.  材料一覧
2.  材料ごとの甘さ・コク・食感への影響値
3.  ☆5評価に使用する内部値域と表示への変換方法
4.  満足度の具体的な計算式
5.  材料をアンロック後に無制限使用可能とするか
6.  レシピ発見条件
7.  各ステージの正確な制限時間（5〜10分を候補）
8.  各ステージの正確な満足度ノルマ（Stage 1は30点程度を候補）
9.  各ステージの全Customer一覧と詳細な好み
10. 各ステージのボスの出現条件・要求・満足度報酬
11. 調理失敗の具体的な判定方法・タイミング・端数処理
12. ミキサーなど未確定の調理器具の具体的操作方法
13. 材料量を連続量・段階式のどちらで扱うか
14. 「調理技術」の成功率上昇量
15. 「ひらめき」のヒント提示確率とヒント内容
16. 「味覚」のレベルごとの情報開示範囲
17. 「コンポタ愛」のステータス・満足度ボーナス量
18. 各能力のレベル上限・レベルアップ条件
19. 各メンバーのScene Ownership

## 23. 開発優先順位

### Priority 1：最小ゲームループ

``` text
Player操作
↓
材料を取得
↓
調理
↓
コンポタ完成
↓
客へ提供
↓
満足度獲得
↓
制限時間終了
↓
Result
```

### Priority 2：ゲーム性

- 複数材料
- 客の好み
- コンポタ評価
- 調理成功・失敗
- ステージノルマ
- ボス

### Priority 3：拡張要素

- レシピ発見
- 料理レベル
- 材料アンロック
- 演出
- Animation
- 効果音

Priority 1が完成するまではPriority 3を優先しない。

## 24. 設計原則

1.  Scene Editorを使用する
2.  大きなSceneを小さなSceneへ分割する
3.  同じ `.tscn` を複数人で同時編集しない
4.  Sceneとゲームロジックを可能な限り分離する
5.  各Sceneを独立して開発・確認できるようにする
6.  Scene間通信はSignal等を利用して依存を減らす
7.  `main` へ直接実装をpushしない
8.  AIも `SPEC.md` に従って実装する
9.  AIは未確定仕様を勝手に確定しない
10. AIが変更したSceneはGodot Editorで人間が確認する
11. ハッカソンでは完全性より、遊べるゲームループの完成を優先する

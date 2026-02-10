# Investigation Protocol

**CRITICAL: 憶測で修正せず、必ずデバッグ出力で事実を確認してから修正すること**

## Fundamental Principles

1. **事実を掴む**: `console.log` でデバッグ出力を入れて、実際の値を確認する
2. **エラーメッセージを正確に読む**: ruby.wasm のスタックトレースは `eval:行番号` で `<script type="text/ruby">` ブロック内の行を指す
3. **一つずつ変数を確認**: 複数の値を一度に出力しようとすると、途中で例外が出て全体が失敗する
   - 例: `.typeof` は OK だが `.class` で落ちる
4. **仮説を立てて検証**: 「`.call()` が駄目なら `method_missing` はどうか？」のように、代替手段を一つずつ試す
   - ブルートフォースで総当たりしない
5. **Chrome で確認**: ページリロード後 Ruby WASM の初期化に時間がかかるため、**25〜30秒待ってから**コンソールを確認する
6. **投機的な修正禁止**: 根拠なく「多分これで直る」という修正をしない

## Investigation Workflow

複雑な問題の場合は、以下の7ステップで調査する：

### 1. 現象の正確な記録

**「何が起きているか」を客観的に記録する：**

```
現象の例：
- ✓ ページ読み込み後、Ruby WASM 初期化に30秒かかる
- ✓ パーティクルは表示されるが、マイク音に反応しない
- ✓ ブラウザコンソールに「TypeError: ... was called on undefined」が出ている
```

**避けるべき記述：**
```
- × 「パーティクルが壊れている」（曖昧）
- × 「Ruby が動かない」（範囲が広い）
- × 「多分 JS::Object のせい」（仮説を事実と混同）
```

### 2. 期待される動作の確認

**「何が起きるべきか」を定義する：**

```
期待される動作の例：
- マイク入力の低音（Bass）に反応して、パーティクルが赤色で爆発する
- トーラスが拡大・回転し、Bloom エフェクトが輝く
- デバッグ情報に Bass/Mid/High の値が表示される
```

### 3. 差分の特定

**「何が違うのか」を明確にする：**

```
差分の例：
- 期待: パーティクルが爆発する
- 実際: パーティクルが静止したままで、色も変わらない
- 差分: AudioAnalyzer が周波数データを取得していない可能性

→ 次は、AudioAnalyzer の出力が正しいかを確認する
```

### 4. 仮説の立案

**最大3つの仮説を立て、各々の根拠を記す：**

```
仮説1: Web Audio API のマイク入力が取得できていない
  根拠: ブラウザコンソールに audio context のエラーが出ていない

仮説2: AudioAnalyzer の周波数帯域計算が間違っている
  根拠: Bass/Mid/High の値が常に 0 で変動しない

仮説3: Ruby→JavaScript のコールバック呼び出しが失敗している
  根拠: JS.global.updateParticles() の実行ログが出ていない
```

### 5. 仮説の検証（デバッグ出力）

**各仮説を一つずつ検証する：**

#### 5.1 Web Audio API の確認

```
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: `
    console.log('AudioContext state:', audioContext?.state);
    console.log('Analyser connected:', !!analyser);
    console.log('Data array length:', dataArray?.length);
  `
)
```

期待される出力：
```
AudioContext state: running
Analyser connected: true
Data array length: 2048
```

#### 5.2 AudioAnalyzer の周波数出力確認

index.html の Ruby コード内に以下を追加：

```ruby
# Ruby コード内
analyser_data = js_analyser_result  # AudioAnalyzer の出力
JS.global[:console].log("[DEBUG] bass=#{analyser_data[:bass]}")
JS.global[:console].log("[DEBUG] mid=#{analyser_data[:mid]}")
JS.global[:console].log("[DEBUG] high=#{analyser_data[:high]}")
```

マイク入力がある場合、これらの値が変動する。

#### 5.3 Ruby→JavaScript コールバック確認

Ruby コード内：

```ruby
# method_missing 経由で呼び出し（.call() は使わない）
JS.global[:console].log("[DEBUG] Calling updateParticles...")
JS.global.updateParticles(positions, colors)
JS.global[:console].log("[DEBUG] updateParticles called successfully")
```

### 6. 修正の実施

**最小限の変更で問題を解決する：**

```ruby
# ❌ ブルートフォース（やってはいけない）
# 複数の行を一度に変更して「多分これで直る」

# ✓ 最小限の修正
# 一つの根本原因を特定して、そこだけ修正
```

### 7. 動作確認

Chrome MCP ツール（`/debug-browser` スキル）で検証：

```
/debug-browser
```

以下の項目を確認：
- ✓ ページ読み込み成功
- ✓ Ruby WASM 初期化成功（30秒以内）
- ✓ コンソールエラーなし
- ✓ 期待される動作が実現している

## Debugging Output Best Practices

### 一つずつ出力する

```ruby
# ❌ 複数の値を一度に出力（途中で例外が出る可能性）
JS.global[:console].log("[DEBUG] obj.typeof=#{obj.typeof}, value=#{obj.value}")

# ✓ 一つずつ出力
JS.global[:console].log("[DEBUG] typeof=#{obj.typeof}")
JS.global[:console].log("[DEBUG] value=#{obj.value}")
```

### JS::Object の値を確認する時の注意

```ruby
# ❌ .class を使う（BasicObject 継承のため、method_missing で JS 側に転送される）
JS.global[:console].log("[DEBUG] type=#{obj.class}")  # NoMethodError

# ✓ .typeof を使う（JS::Object 固有メソッド）
JS.global[:console].log("[DEBUG] typeof=#{obj.typeof}")

# ✓ Ruby に変換してから操作
JS.global[:console].log("[DEBUG] string=#{obj.to_s}")
```

### パターンマッチング

```ruby
# Ruby のコンソール出力を区別しやすくするため、プレフィックスを使う
JS.global[:console].log("[DEBUG] message here")
JS.global[:console].log("[WARN] warning here")
JS.global[:console].log("[ERROR] error here")
```

## Common Error Patterns

### "TypeError: Function.prototype.apply was called on undefined"

根本原因: `JS::Object#call()` メソッドのバグ（js gem 2.8.1）

詳細: [.claude/RUBY-WASM.md](./RUBY-WASM.md#known-issues) を参照

### "NoMethodError: undefined method `class' for #<JS::Object>"

根本原因: `JS::Object` は `BasicObject` を継承しており、`.class` メソッドが存在しない

詳細: [.claude/RUBY-WASM.md](./RUBY-WASM.md#js-object-notes) を参照

### Chrome DevTools での確認

詳細な手順は `/debug-browser` スキルを参照：

```
/debug-browser
```

## Checklist

問題解決前に、以下を確認する：

- [ ] 事実（現象）を正確に記録した
- [ ] 期待される動作を定義した
- [ ] 差分を明確にした
- [ ] 仮説を3つ以下立てた
- [ ] 各仮説の根拠を記した
- [ ] デバッグ出力で一つずつ検証した
- [ ] コンソールエラーを全て確認した
- [ ] 修正は最小限に絞った
- [ ] `/debug-browser` または `/visualizer-test` で動作確認した
- [ ] git の変更内容が意図通りか確認した

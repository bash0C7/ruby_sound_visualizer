# JavaScript-ruby.wasm 連携ガイド

ruby.wasm 環境における Ruby と JavaScript の相互運用パターンを解説する。

## 目次

1. [概要](#概要)
2. [Ruby から JavaScript を呼ぶ](#ruby-から-javascript-を呼ぶ)
3. [JavaScript から Ruby を呼ぶ](#javascript-から-ruby-を呼ぶ)
4. [データ型の変換](#データ型の変換)
5. [JS::Object の注意点](#jsobject-の注意点)
6. [エラーハンドリング](#エラーハンドリング)
7. [デバッグ手法](#デバッグ手法)
8. [パフォーマンス考慮事項](#パフォーマンス考慮事項)
9. [既知の問題と回避策](#既知の問題と回避策)
10. [参考リンク](#参考リンク)

## 概要

ruby.wasm は Ruby インタープリタを WebAssembly にコンパイルしたもの。`js` gem (ruby.wasm に組み込み) を通じて JavaScript の世界と相互にやりとりできる。

```
Ruby 世界 (WASM)          JavaScript 世界 (ブラウザ)
  ├── Ruby オブジェクト    ├── DOM
  ├── クラス/メソッド      ├── Web API
  └── js gem              └── グローバルオブジェクト
       ↕ 相互呼び出し ↕
```

基本原則: `require 'js'` で `JS` モジュールが使えるようになり、`JS.global` が JavaScript の `globalThis` (ブラウザでは `window`) にアクセスするエントリポイントとなる。

## Ruby から JavaScript を呼ぶ

### グローバル関数の呼び出し

```ruby
require 'js'

# JavaScript のグローバル関数を呼ぶ (method_missing 経由)
JS.global.alert("Hello from Ruby!")
JS.global.console.log("Ruby says hi")
JS.global.updateParticles(positions, colors, size, opacity)
```

`JS.global.メソッド名(引数)` が基本パターン。Ruby の `method_missing` が自動的に JavaScript の関数呼び出しに変換する。

### グローバルプロパティの読み書き

```ruby
# 読み取り (ブラケット記法)
value = JS.global[:someProperty]
state = JS.global[:audioContext][:state]

# 書き込み (ブラケット代入)
JS.global[:myVariable] = "hello"
JS.global[:debugInfoText] = formatted_string
```

### オブジェクトのメソッド呼び出し

```ruby
# JavaScript オブジェクトのメソッドを呼ぶ
JS.global[:console].log("message")
JS.global[:audioContext].resume
```

### コンストラクタ (new)

```ruby
# JavaScript の new を Ruby から呼ぶ
audio_context = JS.global[:AudioContext].new
```

## JavaScript から Ruby を呼ぶ

### Ruby lambda のコールバック登録

```ruby
# Ruby lambda を JavaScript のグローバルプロパティとして登録
JS.global[:myCallback] = lambda do |arg1, arg2|
  # arg1, arg2 は JS::Object として受け取る
  # 必要に応じて Ruby 型に変換して処理
  result = arg1.to_f + arg2.to_f
  result  # 返り値は JavaScript に返る
end
```

```javascript
// JavaScript 側から呼び出し
window.myCallback(10, 20);
```

### コールバック設計のベストプラクティス

1. JavaScript 側の関数名は明確なプレフィックスを付ける (`ruby` など)
2. コールバック内で例外をキャッチし、ログに出力する
3. 引数は JavaScript の型で渡されるため、Ruby 側で型変換する

```ruby
JS.global[:rubyUpdateVisuals] = lambda do |freq_array|
  begin
    # JS::Object → Ruby Array に変換
    ruby_array = freq_array.to_a
    # 処理...
  rescue => e
    JS.global[:console].error("Error: #{e.message}")
  end
end
```

## データ型の変換

### Ruby → JavaScript

| Ruby 型 | JavaScript 型 | 注意事項 |
|---------|--------------|---------|
| `Integer` | `Number` | 自動変換 |
| `Float` | `Number` | 自動変換 |
| `String` | `String` | 自動変換 |
| `true`/`false` | `Boolean` | 自動変換 |
| `nil` | `null` | 自動変換 |
| `Array` | Array-like | JS 側で `Array.from()` で変換可能 |
| `Hash` | Object-like | JS 側で変換が必要な場合がある |

### JavaScript → Ruby

| JavaScript 型 | Ruby 型 | 変換方法 |
|--------------|---------|---------|
| `Number` | `JS::Object` | `.to_f` または `.to_i` で変換 |
| `String` | `JS::Object` | `.to_s` で Ruby String に変換 |
| `Array` | `JS::Object` | `.to_a` で Ruby Array に変換 |
| `Boolean` | `JS::Object` | `.to_s == "true"` で判定 |
| `null`/`undefined` | `JS::Object` | `.typeof` で判定 |

### 変換の鉄則

JavaScript から受け取った値は全て `JS::Object` として来る。Ruby のメソッドを使う前に必ず適切な型に変換すること:

```ruby
# NG: JS::Object のまま Ruby メソッドを使う
js_string = JS.global[:location][:search]    # JS::Object
js_string.match(/pattern/)                    # JS の String.match() が呼ばれる!

# OK: Ruby String に変換してから操作
ruby_string = JS.global[:location][:search].to_s   # Ruby String
ruby_string.match(/pattern/)                         # Ruby の正規表現マッチ
```

## JS::Object の注意点

`JS::Object` は Ruby の `BasicObject` を継承している。これは重要な制約を生む。

### BasicObject の影響

`BasicObject` は Ruby のクラス階層の最上位で、ほとんどのメソッドが定義されていない:

```ruby
js_obj = JS.global[:someValue]

# これらは全て NoMethodError になる
js_obj.class      # NG
js_obj.nil?       # NG
js_obj.is_a?      # NG
js_obj.inspect     # NG
js_obj.respond_to? # NG
```

`JS::Object` に対して呼ばれたメソッドは全て `method_missing` 経由で JavaScript のプロパティアクセスに変換される。つまり `js_obj.class` は JavaScript の `obj.class` を探しに行く。

### 型判定の方法

```ruby
# JS::Object の型を調べる
js_obj.typeof    # => "function", "object", "number", "string", "undefined" 等

# Ruby の値として使いたい場合
value = js_obj.to_s  # Ruby String に変換
value = js_obj.to_f  # Ruby Float に変換
value = js_obj.to_i  # Ruby Integer に変換
```

### 文字列補間での落とし穴

```ruby
# NG: 補間内で .class を呼ぶと NoMethodError で落ちる
"type=#{js_obj.class}"

# OK: .typeof を使う
"type=#{js_obj.typeof}"

# OK: .to_s で変換してから補間
"value=#{js_obj.to_s}"
```

## エラーハンドリング

### 基本パターン

```ruby
begin
  JS.global.someFunction(args)
rescue => e
  JS.global[:console].error("Error: #{e.message}")
  JS.global[:console].error(e.backtrace[0..4].join(", "))
end
```

### コールバック内のエラー

JavaScript から呼ばれるコールバック内で例外が発生すると、エラーが JavaScript 側に伝播する。全コールバックに rescue を入れておくのが安全:

```ruby
JS.global[:myCallback] = lambda do |arg|
  begin
    # 処理
  rescue => e
    JS.global[:console].error("[Ruby] #{e.message}")
  end
end
```

## デバッグ手法

### コンソール出力

```ruby
# 基本
JS.global[:console].log("[Ruby] message")

# 変数の出力 (一つずつ!)
JS.global[:console].log("[DEBUG] a=#{a}")
JS.global[:console].log("[DEBUG] b=#{b}")
```

### 一度に複数の変数を出力しない

```ruby
# NG: 途中で例外が出る可能性
JS.global[:console].log("[DEBUG] a=#{a}, b=#{b.class}, c=#{c}")

# OK: 一つずつ出力
JS.global[:console].log("[DEBUG] a=#{a}")
JS.global[:console].log("[DEBUG] b typeof=#{b.typeof}")
JS.global[:console].log("[DEBUG] c=#{c}")
```

`.class` など `BasicObject` にないメソッドが補間中に呼ばれるとそこで例外が発生し、残りの変数が表示されないまま処理が中断される。

### JavaScript 側の値を調べる

```ruby
JS.global[:console].log("[DEBUG] audioContext state=#{JS.global[:audioContext][:state]}")
JS.global[:console].log("[DEBUG] typeof analyser=#{JS.global[:analyser].typeof}")
```

## パフォーマンス考慮事項

### Ruby-JavaScript 境界のコスト

Ruby と JavaScript の間のデータ受け渡しにはオーバーヘッドがある。毎フレーム呼ばれる処理では:

1. JavaScript 呼び出し回数を最小化する (まとめて渡す)
2. 大きな配列は一度にまとめて渡す (要素ごとに渡さない)
3. 文字列フォーマットは Ruby 側で完了させ、完成文字列を一度だけ渡す

### 効率的なデータ受け渡しパターン

```ruby
# NG: 要素ごとに呼ぶ (3000 パーティクル × 毎フレーム = 遅い)
positions.each { |p| JS.global.addPosition(p) }

# OK: 配列をまとめて渡す (1 回の呼び出し)
JS.global.updateParticles(all_positions, all_colors, avg_size, avg_opacity)
```

### 計算の Ruby 側集約

JavaScript 側で行う計算を可能な限り Ruby 側で行い、結果だけを渡す。これにより JavaScript の処理負荷を軽減し、Ruby 側でのテストも容易になる。

### 本プロジェクトの毎フレーム境界呼び出し

`main.rb` から JSBridge 経由で毎フレーム 9 回の境界呼び出しが発生する:

| 呼び出し | データ量 | 呼び出し元 |
|---------|---------|-----------|
| `updateParticles(positions, colors, size, opacity)` | ~9000 floats | `JSBridge.update_particles` |
| `updateGeometry(scale, rotation, emissive, color)` | ~8 values | `JSBridge.update_geometry` |
| `updateBloom(strength, threshold)` | 2 values | `JSBridge.update_bloom` |
| `updateCamera(position, shake)` | 6 values | `JSBridge.update_camera` |
| `updateParticleRotation(rotation)` | 3 values | `JSBridge.update_particle_rotation` |
| `updateVRM(rotations, hipsY, blink, mouthV, mouthH)` | ~47 values | `JSBridge.update_vrm` |
| `updateVRMMaterial(intensity, color)` | 4 values | `JSBridge.update_vrm_material` |
| `window.fpsText = ...` | string (1/sec) | `main.rb` |
| `window.debugInfoText = ...` | string | `main.rb` |

### JSBridge モジュールパターン

本プロジェクトでは `JSBridge` モジュール (`src/ruby/js_bridge.rb`) が全ての Ruby→JS 呼び出しを集約:

```ruby
module JSBridge
  def self.update_particles(data)
    begin
      JS.global.updateParticles(data[:positions], data[:colors], data[:avg_size], data[:avg_opacity])
    rescue => e
      JS.global[:console].error("JSBridge error: #{e.message}")
    end
  end
  # ...
end
```

- 全呼び出しに `rescue` ガードあり
- デバッグログはフレーム数で間引き (`$frame_count % 60 == 0`)

### デルタタイム共有パターン

JS→Ruby 間でデルタタイムを共有するため、`window._animDeltaTime` グローバル変数を使用:

```javascript
// index.html:674
window._animDeltaTime = deltaTime;
```

```ruby
# vrm_dancer.rb:35-36
dt = JS.global[:_animDeltaTime]
delta = dt.typeof == "number" ? dt.to_f : 0.033  # fallback ~30fps
```

### DevTool 設定インターフェース

`Config.register_devtool_callbacks` で Chrome DevTools から動的に設定値を変更できるコールバックを登録:

```javascript
// DevTools コンソールから使用:
rubyConfigSet('sensitivity', 2.0)   // 設定値の変更
rubyConfigGet('sensitivity')         // 現在値の取得
rubyConfigList()                     // 全設定値の一覧
rubyConfigReset()                    // デフォルト値にリセット
```

### ログバッファ (window.logBuffer)

Chrome MCP 連携用のリングバッファ。コンソール出力を全て capture し、DevTools から取得可能:

```javascript
// index.html:140-162
window.logBuffer.getLast(20)   // 直近20件
window.logBuffer.getErrors()   // エラーのみ
window.logBuffer.getRuby()     // Ruby出力のみ
window.logBuffer.getJS()       // JS出力のみ
window.logBuffer.dump()        // 全ログをテキスト出力
```

## 既知の問題と回避策

### JS::Object#call() の TypeError (js gem 2.8.1)

`JS::Object` から関数参照を取り出して `#call()` すると TypeError が発生する:

```ruby
# NG: TypeError: Function.prototype.apply was called on undefined
func = JS.global[:updateParticles]
func.call(args)

# OK: method_missing 経由で呼ぶ
JS.global.updateParticles(args)
```

原因: `#call()` は関数参照を `Reflect.apply` に渡すが、参照が失われる。`method_missing` は `globalThis` から関数を都度解決するため問題なし。

### AudioContext の suspended 状態

Chrome のオートプレイポリシーにより `new AudioContext()` は suspended 状態で作成される:

```ruby
# AudioContext 作成後、明示的に resume が必要
audio_context = JS.global[:AudioContext].new
audio_context.resume
```

JavaScript 側でユーザークリック時の resume フォールバックも用意すること。

## 参考リンク

- [ruby.wasm 公式ドキュメント](https://ruby.github.io/ruby.wasm/)
- [JS モジュール API リファレンス](https://ruby.github.io/ruby.wasm/JS.html)
- [ruby.wasm GitHub リポジトリ](https://github.com/aspect-build/aspect-cli)
- [BasicObject - Ruby リファレンス](https://docs.ruby-lang.org/en/3.4/BasicObject.html)

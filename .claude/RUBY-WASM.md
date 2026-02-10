# Ruby WASM Interop Guide

このファイルは、Ruby WASM と JavaScript 間の相互運用に関する詳細な知見をまとめたもの。

**簡潔な要約は** [~/.claude/projects/.../memory/MEMORY.md](~/.claude/projects/-Users-bash-dev-src-github-com-bash0C7-ruby-sound-visualizer/memory/MEMORY.md) **を参照。**

## Known Issues in js gem 2.8.1

### Bug: JS::Object#call() TypeError

**症状:**
```
TypeError: Function.prototype.apply was called on undefined
```

**根本原因:**
`JS::Object#call()` は内部保持した関数参照を `Reflect.apply` に渡すが、その参照が `undefined` に化ける。

**解決方法: method_missing パターンを使う**

```ruby
# ❌ NG: JS::Object#call
js_func = JS.global[:updateParticles]
js_func.typeof   # => "function"（参照自体は有効）
js_func.call(a, b)  # => TypeError: Function.prototype.apply was called on undefined

# ✓ OK: method_missing → invoke_js_method 経由で正しく動く
JS.global.updateParticles(a, b)  # 成功！
```

**理由:**
- `#call()` は参照を保持したまま `Reflect.apply` に渡す
- `method_missing` は `globalThis` から関数を都度解決して `invoke_js_method` で呼ぶため問題なし

## JS::Object Notes

`JS::Object` は **`BasicObject` を継承**している：

### Ruby ビルトインメソッドは存在しない

```ruby
# ❌ これらは存在しない
js_obj.class    # NoMethodError
js_obj.nil?     # NoMethodError
js_obj.is_a?    # NoMethodError
js_obj.inspect  # NoMethodError

# ✓ 全て method_missing 経由で JS プロパティアクセスに変換される
# 結果として、JS 側の obj.class, obj.nil?, obj.is_a? を探す（存在しない）
```

### デバッグ時は .typeof を使う

```ruby
js_obj = JS.global[:someFunc]
js_obj.typeof   # => "function" （OK: JS::Object 固有メソッド）
js_obj.class    # => NoMethodError （NG: BasicObject に .class はない）
```

### 文字列補間での注意

```ruby
# ❌ 文字列補間内で .class を呼ぶと NoMethodError で落ちる
JS.global[:console].log("class=#{js_obj.class}")

# ✓ .typeof か .to_s を使う
JS.global[:console].log("typeof=#{js_obj.typeof}")
JS.global[:console].log("string=#{js_obj.to_s}")
```

## Ruby String Methods on JS::Object

`JS::Object` に Ruby の文字列メソッド（`.match`, `.include?`, `!=` 等）を使う場合、**必ず `.to_s` で Ruby String に変換**する必要がある。

### 例: URL パラメータの解析

```ruby
# ❌ JS::Object のまま Ruby メソッドを使う
search_params = JS.global[:location][:search]         # => JS::Object
search_params.match(/sensitivity=([0-9.]+)/)          # => JS の String.match() が呼ばれ、Ruby Regexp を渡しても動かない
search_params != ""                                    # => JS 側の比較になり期待通りに動かない

# ✓ .to_s で Ruby String に変換してから操作する
search_str = JS.global[:location][:search].to_s       # => Ruby String
search_str.match(/sensitivity=([0-9.]+)/)             # => 正しく Ruby の正規表現マッチが動く
search_str != ""                                       # => Ruby の比較が正しく動く
```

## Ruby → JavaScript Calling Patterns

### Rule: Always use method_missing pattern

```ruby
# Ruby → JS 関数呼び出しは必ず method_missing 経由で行う
JS.global.funcName(args)  # ✓ 推奨（method_missing → invoke_js_method）
JS.global[:funcName].call(args)  # ✗ 禁止（バグあり）
```

### Passing Ruby data to JavaScript

```ruby
# Ruby Array をそのまま JS 関数に渡す
ruby_array = [1, 2, 3]
JS.global.updateArray(ruby_array)  # JS 側で Array.from() で変換可能

# Ruby Hash を JS 関数に渡す
ruby_hash = { x: 1, y: 2 }
JS.global.updateObject(ruby_hash)  # JS 側で Object 化される
```

## JavaScript → Ruby Callback Patterns

### Registering Ruby lambdas as callbacks

```ruby
# Ruby lambda を JavaScript から呼び出し可能にする
JS.global[:rubyUpdateVisuals] = lambda { |freq_array|
  # freq_array は JS 配列（JS::Object）
  ruby_array = freq_array.to_a  # Ruby Array に変換
  # 処理
}

# JavaScript 側から呼び出し
JS.global.rubyUpdateVisuals(jsArray)
```

### Receiving JS Arrays in Ruby

```ruby
# JavaScript から渡された配列は JS::Object として受け取る
JS.global[:rubyCallback] = lambda { |js_array|
  ruby_array = js_array.to_a  # Ruby Array に変換

  # Ruby Array として操作
  ruby_array.each { |item| ... }
}
```

## Debugging Ruby WASM Code

### Output one variable at a time

```ruby
# ❌ 複数を一度に出力（途中で例外が出る可能性）
JS.global[:console].log("[DEBUG] a=#{a}, b=#{b}, c=#{c}")

# ✓ 一つずつ出力
JS.global[:console].log("[DEBUG] a=#{a}")
JS.global[:console].log("[DEBUG] b=#{b}")
JS.global[:console].log("[DEBUG] c=#{c}")
```

### Type inspection

```ruby
# ❌ .class を使わない（BasicObject 継承のため）
JS.global[:console].log("[DEBUG] #{obj.class}")  # NoMethodError

# ✓ .typeof を使う（JS::Object のみ対応）
JS.global[:console].log("[DEBUG] typeof=#{js_obj.typeof}")

# ✓ .to_s で Ruby に変換してから操作
JS.global[:console].log("[DEBUG] value=#{obj.to_s}")
```

### Dynamic JavaScript debugging

```ruby
# Chrome DevTools で JavaScript を実行して、Ruby WASM の状態を確認
JS.global[:console].log("[DEBUG] audioContext=#{JS.global[:audioContext].typeof}")
JS.global[:console].log("[DEBUG] analyser=#{JS.global[:analyser].typeof}")
```

## AudioContext Initialization

### Chrome の autoplay policy への対応

Chrome のオートプレイポリシーにより、`new AudioContext()` は `suspended` 状態で作成される。

```ruby
# AudioContext 作成直後に明示的に resume() を呼ぶ
audio_context = JS.global[:AudioContext].new
audio_context.resume  # 必須
```

### フォールバック: ユーザークリック時の resume

```javascript
// JavaScript 側（index.html）
document.addEventListener('click', () => {
  if (audioContext.state === 'suspended') {
    audioContext.resume();
  }
}, { once: true });
```

## Implementation Tips

### Best Practices

1. **Ruby → JS 関数呼び出し**: 必ず `JS.global.funcName(args)` 形式（method_missing 経由）
2. **JS → Ruby コールバック**: `JS.global[:name] = lambda { |args| ... }` で登録
3. **JS Array の受け取り**: Ruby lambda の引数として渡された JS Array は `.to_a` で変換
4. **Ruby Array の受け渡し**: Ruby Array をそのまま JS 関数に渡す（JS側で Array.from() 対応）
5. **JS の値を Ruby で操作**: `JS::Object` の戻り値に `.to_s` を使う
6. **URL のキャッシュ回避**: `?nocache=<random>` をクエリパラメータに付ける
7. **AudioContext 初期化**: `audioContext.resume()` を明示的に呼ぶ

### Anti-Patterns

❌ `JS::Object#call()` を使う
❌ `JS::Object` に `.class` を呼ぶ
❌ 複数の値を一度にログ出力する
❌ JS::Object に Ruby 文字列メソッドを `.to_s` なしで使う
❌ AudioContext を suspended 状態のまま使う

## References

- [ruby.wasm Official Documentation](https://ruby.github.io/ruby.wasm/)
- [JavaScript Interop - ruby.wasm](https://ruby.github.io/ruby.wasm/JS.html)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)

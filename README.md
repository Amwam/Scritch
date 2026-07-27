
<p align="center">
  <img src="Scritch/Documentation/Images/icon.png?raw=true" width="128" alt="Scritch icon">
</p>

# Scritch.

> **Scritch is a fork of [Boop](https://github.com/IvanMathy/Boop)** by [Ivan Mathy](https://github.com/IvanMathy).
> All the original ideas, design and the vast majority of the code are theirs — Scritch just takes it in
> its own direction. Please go star the [upstream project](https://github.com/IvanMathy/Boop).

<p align="center">
  <img src="Scritch/Documentation/Images/UI.png?raw=true" width="663" alt="UI Screenshot">
</p>

<p align="center">
  <a href="https://github.com/Amwam/Scritch/blob/main/Scritch/Documentation/Readme.md">Documentation</a>  •  <a href="https://github.com/Amwam/Scritch/tree/main/Scripts">Find more scripts</a>
</p>

Scritch is a scriptable scratchpad for developers. Paste some text in, run a transformation on it —
format some JSON, decode a JWT, hash a string, convert CSV to JSON — and copy the result back out.
No files, no projects, no ceremony.

### How to get Scritch

Scritch has no packaged releases yet, so for now you build it from source:

- Clone or download a copy of the repository
- Open `Scritch/Scritch.xcodeproj`
- Press play

If you want a ready-made, signed, App Store-distributed build today, you want
[Boop](https://github.com/IvanMathy/Boop) instead.

### Scripts

Scritch runs the same JavaScript transformation scripts as Boop, so **scripts written for Boop work
here unmodified**. Both module prefixes resolve:

```js
const { encode } = require('@scritch/base64')  // preferred
const { encode } = require('@boop/base64')     // still supported
```

See [Custom scripts](Scritch/Documentation/CustomScripts.md) to write your own.

### Documentation

- [Documentation](Scritch/Documentation/Readme.md)
- [Custom scripts](Scritch/Documentation/CustomScripts.md)
- [Modules](Scritch/Documentation/Modules.md)
- [Debugging scripts](Scritch/Documentation/Debugging.md)

### License

Scritch inherits Boop's license — see [LICENSE](LICENSE). Original copyright remains with the
upstream authors.

# itchio-ios-webview-shell

把 Unity WebGL 网页游戏套成 iOS App 的壳（本地服务器 + WKWebView），不用游戏源码、不用重编译 Unity 工程。

原理：游戏静态文件放进 App bundle 的 `www/`，由 GCDWebServer 在 `127.0.0.1` 上提供 HTTP 服务，WKWebView 加载 `http://127.0.0.1:8080/index.html`。同源加载，Unity WebGL 正常跑，断网也能玩。

> 本仓库**只有壳代码，不含任何游戏文件**。把你自己合法获取的网页游戏（index.html + Build 等资源）放进 `www/` 再编译。

## 结构

```
├── itchio/
│   ├── AppDelegate.swift
│   ├── ViewController.swift   # GCDWebServer + WKWebView，wasm MIME、Range、热降级
│   ├── Info.plist             # 端口 / 入口 / 横屏 / ATS 本地网络
│   └── Assets.xcassets/       # 空 AppIcon，自己放 1024x1024 图标
├── project.yml                # XcodeGen 工程定义（Bundle ID 占位 com.yourname.itchio）
├── Podfile                    # 依赖 GCDWebServer
└── .github/workflows/build.yml # GitHub Actions 云编译 unsigned IPA
```

## 怎么用

1. 把游戏文件放进 `www/`（网页游戏根目录：index.html、Build/ 等），图片图标放进 AppIcon；
2. 改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`（换成你自己的，比如 `com.xxx.yyy`）；
3. 推送到自己的 GitHub 仓库，Actions 会自动编译并产出 **unsigned IPA**（`CODE_SIGNING_ALLOWED=NO`）；
4. 下载 IPA，用你自己的证书/工具签名（比如爱思助手、Sideloadly、zsign、lcsign），装到手机。

也可以在本地 Mac 上编译：

```bash
brew install xcodegen
xcodegen generate
pod install
xcodebuild -workspace itchio.xcworkspace -scheme itchio -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
```

## 配置说明

- 端口和入口：改 `Info.plist` 的 `LocalServerPort`（默认 8080）、`EntryPath`（默认 /index.html），不用动代码；
- ATS：只放开本地回环明文（`NSAllowsLocalNetworking`），不放开外网明文；
- 界面方向：默认横屏（LandscapeLeft/Right），竖屏游戏改 `Info.plist` 的 `UISupportedInterfaceOrientations`；
- 发热处理：`ViewController.swift` 监听系统热状态，过热时调用网页的 `__itchioSetThermalFactor(2)` 降帧，平时满帧；
- 代码里搜 `itchio` 全局替换成你的 App 名即可。

## 已知坑（都处理好了，别回退）

- **libarclite 链接错误**：新版 Xcode 移除了旧部署目标的 ARC 兼容库，`Podfile` 里 post_install 把所有 pod 部署目标强制提到 15.0；
- **.wasm 必须返回 `application/wasm`**：`ViewController.swift` 单独注册了 wasm 的 MIME handler，否则 WebAssembly 加载失败黑屏；
- **文件加载同源**：必须走本地 HTTP（127.0.0.1），不要直接 `file://` 加载，WebKit 会因 CORS 拦 Unity 的子资源请求；
- **IPA 未签名**：编译产物不带签名，装手机前必须自己重签。

## 许可证

- 本仓库代码 MIT，见 [LICENSE](LICENSE)
- 用到 [GCDWebServer](https://github.com/swisspol/GCDWebServer)（BSD 3-Clause，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)）

游戏文件版权归原作者所有，请只放你合法获取的内容。

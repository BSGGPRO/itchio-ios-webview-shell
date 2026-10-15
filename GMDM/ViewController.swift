import UIKit
import WebKit
import GCDWebServer

/// 本地 HTTP 服务器 + WKWebView 壳。
/// 游戏文件放在 App bundle 的 www/ 目录，由 GCDWebServer 在 127.0.0.1 上提供 HTTP 服务，
/// WKWebView 加载 http://127.0.0.1:<port>/index.html —— 同源加载，Unity WebGL 可正常运行。
final class ViewController: UIViewController {

    private var webView: WKWebView!
    private var server: GCDWebServer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 智能热降级：监听系统热状态，过热时让网页降到 30fps，平时保持 60fps 满帧（不牺牲体验）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil)

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        // 黑底：即使游戏画布比例与屏幕有差异，留边也是黑色（Unity 默认黑底），而不是白条
        view.backgroundColor = .black
        webView.isOpaque = false
        webView.backgroundColor = .black
        view.addSubview(webView)

        startLocalServer()

        // 入口 URL 由 Info.plist 的 LocalServerPort / EntryPath 控制，改 plist 即可，不用改代码
        let port = Bundle.main.object(forInfoDictionaryKey: "LocalServerPort") as? Int ?? 8080
        let entry = Bundle.main.object(forInfoDictionaryKey: "EntryPath") as? String ?? "/index.html"
        if let url = URL(string: "http://127.0.0.1:\(port)\(entry)") {
            webView.load(URLRequest(url: url))
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    }

    /// 系统热状态变化：serious/critical（过热）→ 网页再降一半帧率；正常 → 恢复
    @objc private func thermalStateChanged() {
        let factor: Int
        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical:
            factor = 2
        default:
            factor = 1
        }
        let js = "window.__gmdmSetThermalFactor && window.__gmdmSetThermalFactor(\(factor))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func startLocalServer() {
        guard let wwwDir = Bundle.main.path(forResource: "www", ofType: nil) else {
            print("[GMDM] www directory not found in bundle")
            return
        }

        let srv = GCDWebServer()

        // 关键：.wasm 必须返回 application/wasm MIME，
        // Unity loader 的 WebAssembly.instantiateStreaming 依赖它，否则 wasm 加载失败。
        srv.addHandler(forMethod: "GET",
                       pathRegex: ".*\\.wasm(\\.gz)?$",
                       request: GCDWebServerRequest.self) { [wwwDir] request in
            let rawPath = request.url.path
            let decodedPath = rawPath.removingPercentEncoding ?? rawPath
            let filePath = wwwDir + decodedPath
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                return GCDWebServerResponse(statusCode: 404)
            }
            return GCDWebServerDataResponse(data: data, contentType: "application/wasm")
        }

        // 其余静态文件（index.html / .js / .data.gz / .framework.js.gz / 图片等）：
        // 带 Range 支持（媒体/大文件流式）、默认 index.html、0 秒缓存。
        srv.addGETHandler(forBasePath: "/",
                          directoryPath: wwwDir,
                          indexFilename: "index.html",
                          cacheAge: 0,
                          allowRangeRequests: true)

        // GCDWebServerOption_* 是 ObjC 宏（本质是字符串常量），Swift 中不可见，
        // 直接用字面量 key：Port + BindToLocalhostOnly（只绑 127.0.0.1，不暴露局域网）
        let port = Bundle.main.object(forInfoDictionaryKey: "LocalServerPort") as? Int ?? 8080
        do {
            try srv.start(options: [
                "Port": UInt(port),
                "BindToLocalhostOnly": true
            ])
            print("[GMDM] local server started on 127.0.0.1")
        } catch {
            print("[GMDM] server start failed: \(error)")
        }
        server = srv
    }
}

extension ViewController: WKNavigationDelegate {
    // 页面加载完成后同步一次当前热状态（否则页面在过热期间才加载完会错过降级）
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        thermalStateChanged()
    }
}

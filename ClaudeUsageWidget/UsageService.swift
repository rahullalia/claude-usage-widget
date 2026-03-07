import Foundation
import WebKit

protocol UsageServiceDelegate: AnyObject {
    func usageService(_ service: UsageService, didUpdate data: UsageData)
    func usageService(_ service: UsageService, didFailWith error: UsageServiceError)
}

enum UsageServiceError: Error, Equatable {
    case notAuthenticated
    case networkError(String)
    case parseError(String)
    case orgIdNotFound
}

class UsageService: NSObject {
    weak var delegate: UsageServiceDelegate?
    private weak var webView: WKWebView?
    private var timer: Timer?
    private var cachedOrgId: String?
    private(set) var lastData: UsageData?

    init(webView: WKWebView) {
        self.webView = webView
    }

    // Start polling every 5 minutes. Also fetches immediately.
    func startPolling() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    // Manual refresh trigger
    func fetch() {
        guard let webView = webView else {
            delegate?.usageService(self, didFailWith: .notAuthenticated)
            return
        }

        if let orgId = cachedOrgId {
            fetchUsage(webView: webView, orgId: orgId)
        } else {
            resolveOrgId(webView: webView) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let orgId):
                    self.cachedOrgId = orgId
                    self.fetchUsage(webView: webView, orgId: orgId)
                case .failure(let error):
                    self.delegate?.usageService(self, didFailWith: error)
                }
            }
        }
    }

    // MARK: - Internal fetch steps

    private func resolveOrgId(webView: WKWebView, completion: @escaping (Result<String, UsageServiceError>) -> Void) {
        let js = "fetch('https://claude.ai/api/organizations').then(r => r.json()).then(d => JSON.stringify(d))"
        webView.evaluateJavaScript(js) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error.localizedDescription)))
                    return
                }
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let orgs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let firstOrg = orgs.first,
                      let uuid = firstOrg["uuid"] as? String else {
                    completion(.failure(.orgIdNotFound))
                    return
                }
                completion(.success(uuid))
            }
        }
    }

    private func fetchUsage(webView: WKWebView, orgId: String) {
        let url = "https://claude.ai/api/organizations/\(orgId)/usage"
        let js = "fetch('\(url)').then(r => r.json()).then(d => JSON.stringify(d))"
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.delegate?.usageService(self, didFailWith: .networkError(error.localizedDescription))
                    return
                }
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8) else {
                    self.delegate?.usageService(self, didFailWith: .parseError("Invalid response"))
                    return
                }
                do {
                    let usageData = try UsageData.decode(from: data)
                    self.lastData = usageData
                    self.delegate?.usageService(self, didUpdate: usageData)
                } catch {
                    self.delegate?.usageService(self, didFailWith: .parseError(error.localizedDescription))
                }
            }
        }
    }

    // Clears the cached org ID (e.g., after sign-out)
    func resetCache() {
        cachedOrgId = nil
        lastData = nil
    }
}

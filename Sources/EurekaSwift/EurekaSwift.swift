import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OpenCombine
import OpenCombineFoundation
import NIO
import NIOCronScheduler

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public final class Eureka {
    /// Eureka Server Address, suck as: http://127.0.0.1:8080/eureka/
    public let serverAddress: URL
    /// Eureka Server API VERSION, default v1
    public let apiVersion: APIVersion
    /// Log
    public let logEnabled: Bool
    /// Instance being register to Eureka
    public private(set) var instance: Instance?
    private let session: URLSession
    private let eventLoop: NIO.EventLoop
    private var cancelBag: AnyCancellable?
    private var job: NIOCronJob?
    
    /// Eureka instance
    /// - Parameters:
    ///   - serverAddress: Eureka server address
    ///   - apiVersion: api version, defautl .v1
    public init(serverAddress: URL, apiVersion: APIVersion = .v1, logEnabled: Bool = false, eventLoop: NIO.EventLoop) {
        self.serverAddress = serverAddress
        self.apiVersion = apiVersion
        self.logEnabled = logEnabled
        self.eventLoop = eventLoop
        session = URLSession.shared
    }
    
    /// Get multiple instances from eureka servers string
    /// like http://127.0.0.1:8088/eureka/,http://127.0.0.2:8088/eureka/,http://127.0.0.3:8088/eureka/
    /// - Parameters:
    ///   - urls: stirng that contain eureka servers, using "," to seperate
    ///   - apiVersion: api version, defautl .v1
    /// - Returns: [Eureka]
    public static func from(urls: String, apiVersion: APIVersion = .v1, logEnabled: Bool, eventLoop: NIO.EventLoop) -> [Eureka] {
        return urls.components(separatedBy: ",").compactMap { URL(string: $0) }.map { Eureka(serverAddress: $0, apiVersion: apiVersion, logEnabled: logEnabled, eventLoop: eventLoop) }
    }

    /// Register new application instance
    ///
    /// POST /eureka/apps/appID
    ///
    /*
    ```shell
        curl --header "Content-Type: application/json" \
          --request POST \
          --data '{"app":"5.2.0","flutter":"2.2.0"}' \
        http://10.250.100.71:8761/eureka/apps/nit-ts-app-server
    ```
     */
    ///
    /// - Parameters:
    ///   - instance: Instance being register to Eureka
    /// - Returns: AnyPublisher<Bool, Never>
    public func register(instance: Instance) throws -> AnyPublisher<Bool, Never> {
        if self.instance != nil {
            return Just(true).eraseToAnyPublisher()
        }
        self.instance = instance
        return request(path: "apps/\(instance.appID)", method: .post) { req in
            let json = instance.toJson()
            var request = req
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [])
            return request
        }
        .map { [weak self] _, resp in
            // https://github.com/Netflix/eureka/wiki/Eureka-REST-operations
            let isSuccess = resp.statusCode == 204
            if let sself = self {
                sself.flog("\(isSuccess ? "✅": "❌") register: \(instance.app)", stdout)
                sself.activeHeartbeat()
            }
            return isSuccess
        }
        .eraseToAnyPublisher()
    }
    
    /// De-register application instance
    /// DELETE /eureka/apps/appID/instanceID
    /// - Returns: AnyPublisher<Bool, Never>
    public func deregister() -> AnyPublisher<Bool, Never> {
        guard let ins = instance else {
            return Just(true).eraseToAnyPublisher()
        }
        return request(path: "apps/\(ins.appID)/\(ins.instanceId)", method: .delete).map { [weak self] data, resp in
            let isOK = resp.statusCode == 200
            let isSuccess = isOK
            if isSuccess {
                if let sself = self {
                    sself.flog("\(isSuccess ? "✅": "❌") deregister: \(ins.app)", stdout)
                    sself.instance = nil
                    sself.deactiveHeartbeat()
                }
            }
            return isSuccess
        }.eraseToAnyPublisher()
    }
    
    private func activeHeartbeat() {
        job?.cancel()
        
        /**
         * * * * *  command to execute
         ┬ ┬ ┬ ┬ ┬
         │ │ │ │ │
         │ │ │ │ │
         │ │ │ │ └───── day of week (0 - 7) (0 to 6 are Sunday to Saturday, or use names; 7 is Sunday, the same as 0)
         │ │ │ └────────── month (1 - 12)
         │ │ └─────────────── day of month (1 - 31)
         │ └──────────────────── hour (0 - 23)
         └───────────────────────── min (0 - 59)
         */
        job = try? NIOCronScheduler.schedule("* * * * *", on: eventLoop) { [weak self] in
            guard let sself = self else { return }
            sself.sendHeartbeat()
        }
        sendHeartbeat()
    }
    
    
    private func deactiveHeartbeat() {
        job?.cancel()
    }
    
    /// Send application instance heartbeat
    /// PUT /eureka/apps/appID/instanceID
    private func sendHeartbeat() {
        guard let ins = instance else { return }
        cancelBag?.cancel()
        cancelBag = request(path: "apps/\(ins.appID)/\(ins.instanceId)", method: .put).sink { [weak self] _, resp in
            guard let sself = self else { return }
            sself.flog("❤️@\(resp.statusCode)\n", stdout)
        }
    }
    
    func buildURL(with path: String) -> URL {
        let eureka = "eureka"
        let eurekaSlash = "\(eureka)/"
        let slashEureka = "/\(eureka)"
        let baseURL = serverAddress.absoluteString.replacingOccurrences(of: eurekaSlash, with: "").replacingOccurrences(of: eureka, with: "")
        let basePath = path.replacingOccurrences(of: eureka, with: "").replacingOccurrences(of: slashEureka, with: "")
        let version: UInt? = apiVersion == .v1 ? nil : apiVersion.rawValue
        var u = URL(string: baseURL)!
        u = u.appendingPathComponent(eureka)
        if let v = version {
            u = u.appendingPathComponent("v\(v)")
        }
        u = u.appendingPathComponent(basePath)
        return u
    }

    private func request(path: String, method: Method, buildRequest: (URLRequest) -> URLRequest = { $0 }) -> AnyPublisher<(Data, HTTPURLResponse), Never> {
        let url =  buildURL(with: path)
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue.uppercased()
        req = buildRequest(req)
        let p = URLSession.OCombine(session).dataTaskPublisher(for: req).map { [weak self] (data: Data, response: URLResponse) in
            let resp = response as! HTTPURLResponse
            if let sself = self {
                let info = resp.description
                sself.flog(info, stdout)
                if let d = String(data: data, encoding: .utf8) {
                    sself.flog(d, stdout)
                }
            }
            return (data, resp)
        }
        .replaceError(with: (Data(), HTTPURLResponse(url: URL(string: "http://abc.com")!, statusCode: 999, httpVersion: nil, headerFields: nil)!))
        #if DEBUG
        return p.print().eraseToAnyPublisher()
        #else
        return p.eraseToAnyPublisher()
        #endif
    }
    
    private func flog(_ str: String, _ to: UnsafeMutablePointer<FILE>) {
        guard logEnabled else { return }
        fputs("[Eureka]<\(Date())> \(str)", to)
    }
}

extension Eureka {
    /// Eureka 注册信息
    public struct Instance: CustomStringConvertible {
        /// 应用名称，例如 nit-xxx-xxx
        public let app: String
        /// 服务器 IP, 例如 127.0.0.1
        public let ipAddr: String
        /// 状态
        public let status: Status
        /// 端口
        public let port: UInt
        /// appID
        public var appID: String { app.uppercased() }
        /// 实例 id, aka instanceID
        public var instanceId: String { "\(ipAddr):\(app.lowercased()):\(port)" }
        /// 同 服务器 IP
        var hostName: String { ipAddr }
        /// 客户端每隔n秒向服务端发送数据包, 心跳包
        public var renewalIntervalInSecs: UInt { 60 }
        /// 客户端告知服务端：若在n秒内没有向服务器发送信息，则服务端将其从服务列表中删除
        public var durationInSecs: UInt { 120 }
        
        public init(app: String, ipAddr: String, status: Status, port: UInt) {
            self.app = app
            self.ipAddr = ipAddr
            self.status = status
            self.port = port
        }
        
        public var description: String {
            return "app: \(app), ipAddr: \(ipAddr), status: \(status), port: \(port)"
        }

        func toJson() -> [String : Any] {
            let appLowercased = app.lowercased()
            return ["instance" : [
                "instanceId": instanceId,
                "app": appID,
                "ipAddr": ipAddr,
                "hostName": hostName,
                "status": status.rawValue.uppercased(),
                "overriddenstatus": "UNKNOWN",
                "port": ["$": "\(port)", "@enabled": true],
                "securePort": ["$": "443", "@enabled": false],
                "countryId": 1,
                "dataCenterInfo": [
                    "@class": "com.netflix.appinfo.InstanceInfo$DefaultDataCenterInfo",
                    "name": "MyOwn"
                ],
                "leaseInfo": [
                    "renewalIntervalInSecs": renewalIntervalInSecs,
                    "durationInSecs": durationInSecs
                ],
                "vipAddress": appLowercased,
                "secureVipAddress": appLowercased,
                "isCoordinatingDiscoveryServer": false
            ]] as [String : Any]
        }
    }
    
    /// Instance Status
    public enum Status: String {
        case up, down, starting, out_of_service, unknown
    }
    
    
    /// Eureka API Version
    public struct APIVersion: RawRepresentable {
        public let rawValue: UInt
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public static let v1 = APIVersion(rawValue: 1)
        public static let v2 = APIVersion(rawValue: 2)
    }
    
    /// Http Method
    enum Method: String {
        case put, delete, post
    }
}

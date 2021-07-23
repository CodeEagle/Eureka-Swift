import XCTest
import OpenCombine
import NIO
@testable import EurekaSwift

final class EurekaSwiftTests: XCTestCase {
    var cancelBags: Set<AnyCancellable> = []
    private var group: EventLoopGroup!
    private var eventLoop: EventLoop!
    
    override func setUp() {
         super.setUp()
         self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
         self.eventLoop = self.group.next()
     }

     override func tearDown() {
         XCTAssertNoThrow(try self.group?.syncShutdownGracefully())
         self.group = nil
         self.eventLoop = nil
         super.tearDown()
     }

    func testBuildURL() {
        
        let expectURL = "http://10.250.100.71:8761/eureka/apps/nit-ts-app-server"
        [
            "http://10.250.100.71:8761/eureka/",
            "http://10.250.100.71:8761/eureka",
            "http://10.250.100.71:8761/",
            "http://10.250.100.71:8761"
        ]
        .map{ URL(string:$0)! }
        .map{ Eureka(serverAddress: $0, eventLoop: eventLoop) }
        .forEach { cli in
            let url = cli.buildURL(with: "apps/nit-ts-app-server").absoluteString
            assert(url == expectURL)
            
            let url2 = cli.buildURL(with: "/apps/nit-ts-app-server").absoluteString
            assert(url2 == expectURL)
        }
    }

    func testEureka() throws {
        let localEureka = URL(string: "http://10.250.100.71:8761/eureka/")!
        let eureka = Eureka(serverAddress: localEureka, logEnabled: true, eventLoop: eventLoop)
        try asyncTest(timeout: 200) { e in
            try eureka.register(instance: .init(app: "nit-ts-app-server", ipAddr: "10.250.100.71", status: .up, port: 9527)).sink(receiveValue: { isSuccess in
                assert(isSuccess)
                DispatchQueue.main.asyncAfter(deadline: .now() + 70) {
                    eureka.deregister().sink { isDeregisterSuccess in
                        assert(isDeregisterSuccess)
                        e.fulfill()
                    }.store(in: &self.cancelBags)
                }
            }).store(in: &cancelBags)
        }
    }
    
}

extension XCTestCase {
    func asyncTest(timeout: TimeInterval = 30, block: (XCTestExpectation) throws -> ()) throws {
        let expectation: XCTestExpectation = self.expectation(description: "❌:Timeout")
        try block(expectation)
        self.waitForExpectations(timeout: timeout) { (error) in
            if let err = error {
                XCTFail("time out: \(err)")
            } else {
                XCTAssert(true, "success")
            }
        }
    }
}

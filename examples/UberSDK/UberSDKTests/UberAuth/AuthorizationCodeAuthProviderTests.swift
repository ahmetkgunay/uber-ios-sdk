//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//


@testable import UberCore
@testable import UberAuth
import XCTest

final class AuthorizationCodeAuthProviderTests: XCTestCase {

    private let configurationProvider = ConfigurationProvidingMock(
        clientID: "test_client_id",
        redirectURI: "test://app"
    )
    
    func test_executeInAppLogin_createsAuthenticationSession() {
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider
        )
                
        XCTAssertNil(provider.currentSession)
        
        provider.execute(
            authDestination: .inApp,
            prefill: nil,
            completion: { _ in }
        )
        
        XCTAssertNotNil(provider.currentSession)
    }
    
    func test_executeInAppLogin_existingSessionBlocksRequest() {
        
        let provider = AuthorizationCodeAuthProvider()
        
        let authSession = AuthenticationSessioningMock()
        provider.currentSession = authSession
        
        XCTAssertEqual(authSession.startCallCount, 0)
        
        provider.execute(
            authDestination: .inApp,
            prefill: nil,
            completion: { _ in }
        )
        
        XCTAssertEqual(authSession.startCallCount, 0)
    }

    func test_execute_existingSession_returnsExistingAuthSessionError() {
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider
        )
        
        provider.execute(
            authDestination: .inApp,
            prefill: nil,
            completion: { _ in }
        )
        
        let expectation = XCTestExpectation()
        
        provider.execute(
            authDestination: .inApp,
            prefill: nil,
            completion: { result in
                switch result {
                case .failure(.existingAuthSession):
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
        )
        
        wait(for: [expectation], timeout: 0.1)
    }
    
    func test_invalidRedirectURI_returnsInvalidRequestError() {
        
        let configurationProvider = ConfigurationProvidingMock(
            clientID: "",
            redirectURI: "uber"
        )
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider
        )
        
        let expectation = XCTestExpectation()
        
        provider.execute(
            authDestination: .inApp,
            prefill: nil,
            completion: { result in
                switch result {
                case .failure(.invalidRequest):
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
        )
        
        wait(for: [expectation], timeout: 0.1)
    }
    
    func test_executeNativeLogin_queriesInstalledApps() {
                
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider
        )
            
        var apps = UberApp.allCases
        let appCount = apps.count
        
        configurationProvider.isInstalledHandler = { app, defaultIfUnregistered in
            // Ensure called once per app
            if !apps.contains(app) {
                XCTFail()
            }
            apps.removeAll(where: { $0 == app })
            return false
        }
        
        XCTAssertEqual(configurationProvider.isInstalledCallCount, 0)
        
        provider.execute(
            authDestination: .native(appPriority: apps),
            prefill: nil,
            completion: { _ in }
        )
        
        XCTAssertEqual(configurationProvider.isInstalledCallCount, appCount)
    }
    
    func test_executeNativeLogin_stopsAfterFirstAppFound() {
                
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider
        )
            
        var apps = UberApp.allCases
        let appCount = apps.count
        
        configurationProvider.isInstalledHandler = { app, _ in
            // Ensure called once per app
            if !apps.contains(app) {
                XCTFail()
            }
            apps.removeAll(where: { $0 == app })
            return true
        }
        
        XCTAssertEqual(configurationProvider.isInstalledCallCount, 0)
        
        provider.execute(
            authDestination: .native(appPriority: apps),
            prefill: nil,
            completion: { _ in }
        )
        
        XCTAssertEqual(configurationProvider.isInstalledCallCount, 1)
        XCTAssertEqual(apps.count, appCount - 1)
    }
    
    func test_executeNativeLogin_triggersApplicationLauncher() {
                
        let applicationLauncher = ApplicationLaunchingMock()
        applicationLauncher.openHandler = { _, _, _ in }
        
        configurationProvider.isInstalledHandler = { _, _ in
            true
        }
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider,
            applicationLauncher: applicationLauncher
        )
        
        XCTAssertEqual(applicationLauncher.openCallCount, 0)
        
        provider.execute(
            authDestination: .native(appPriority: UberApp.allCases),
            prefill: nil,
            completion: { _ in }
        )
        
        XCTAssertEqual(applicationLauncher.openCallCount, 1)
    }
    
    func test_executeNativeLogin_noDestinations_triggersInAppLogin() {
                
        let applicationLauncher = ApplicationLaunchingMock()
        applicationLauncher.openHandler = { _, _, _ in }
        
        configurationProvider.isInstalledHandler = { _, _ in
            false
        }
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider,
            applicationLauncher: applicationLauncher
        )
        
        XCTAssertNil(provider.currentSession)
        
        provider.execute(
            authDestination: .native(appPriority: UberApp.allCases),
            prefill: nil,
            completion: { _ in }
        )
        
        XCTAssertNotNil(provider.currentSession)
    }
    
    func test_executeNativeLogin_noOpens_triggersInAppLogin() {
                
        let applicationLauncher = ApplicationLaunchingMock()
        applicationLauncher.openHandler = { _, _, completion in
            completion?(false)
        }
        
        configurationProvider.isInstalledHandler = { _, _ in
            true
        }
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider,
            applicationLauncher: applicationLauncher
        )
        
        XCTAssertNil(provider.currentSession)
        
        provider.execute(
            authDestination: .native(appPriority: UberApp.allCases),
            prefill: nil,
            completion: { _ in }
        )
        
        XCTAssertNotNil(provider.currentSession)
    }
    
    func test_handleResponse_true_callsResponseParser() {
        
        let responseParser = AuthorizationCodeResponseParsingMock()
        responseParser.isValidResponseHandler = { _, _ in
            true
        }
        responseParser.callAsFunctionHandler = { _ in
            .success(Client())
        }
        
        let provider = AuthorizationCodeAuthProvider(
            responseParser: responseParser
        )
                
        let url = URL(string: "scheme://host?code=123")!
        
        let completion: AuthorizationCodeAuthProvider.Completion = { _ in }
        provider.execute(authDestination: .native(appPriority: []), prefill: nil, completion: completion)
        
        XCTAssertEqual(responseParser.isValidResponseCallCount, 0)
        XCTAssertEqual(responseParser.callAsFunctionCallCount, 0)
        
        let handled = provider.handle(
            response: url
        )
        
        XCTAssertEqual(responseParser.isValidResponseCallCount, 1)
        XCTAssertEqual(responseParser.callAsFunctionCallCount, 1)
        XCTAssertTrue(handled)
    }
    
    func test_handleResponse_false_doesNotTriggerParse() {
        
        let responseParser = AuthorizationCodeResponseParsingMock()
        responseParser.isValidResponseHandler = { _, _ in
            false
        }
        responseParser.callAsFunctionHandler = { _ in
            .success(Client())
        }
        
        let provider = AuthorizationCodeAuthProvider(
            responseParser: responseParser
        )
        
        let url = URL(string: "scheme://host?code=123")!
        
        let completion: AuthorizationCodeAuthProvider.Completion = { _ in }
        provider.execute(authDestination: .native(appPriority: []), prefill: nil, completion: completion)
        
        XCTAssertEqual(responseParser.isValidResponseCallCount, 0)
        XCTAssertEqual(responseParser.callAsFunctionCallCount, 0)
        
        let handled = provider.handle(
            response: url
        )
        
        XCTAssertEqual(responseParser.isValidResponseCallCount, 1)
        XCTAssertEqual(responseParser.callAsFunctionCallCount, 0)
        XCTAssertFalse(handled)
    }
    
    func test_prefill_executesParRequest() {
        
        var hasCalledParRequest = false
        
        let networkProvider = NetworkProvidingMock()
        networkProvider.executeHandler = { request, _ in
            if request is ParRequest {
                hasCalledParRequest = true
            }
        }
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider,
            networkProvider: networkProvider
        )
        
        provider.execute(
            authDestination: .native(appPriority: [.rides]),
            prefill: Prefill(),
            completion: { _ in }
        )
        
        XCTAssertTrue(hasCalledParRequest)
    }
    
    func test_noPrefill_doesNotExecuteParRequest() {
        
        var hasCalledParRequest = false
        
        let networkProvider = NetworkProvidingMock()
        networkProvider.executeHandler = { request, _ in
            if request is ParRequest {
                hasCalledParRequest = true
            }
        }
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider,
            networkProvider: networkProvider
        )
        
        provider.execute(
            authDestination: .native(appPriority: [.rides]),
            completion: { _ in }
        )
        
        XCTAssertFalse(hasCalledParRequest)
    }
    
    func test_nativeAuth_tokenExchange_triggersTokenRequest() {
        
        var hasCalledTokenRequest = false
        
        let networkProvider = NetworkProvidingMock()
        networkProvider.executeHandler = { request, _ in
            if request is TokenRequest {
                hasCalledTokenRequest = true
            }
        }
        
        configurationProvider.isInstalledHandler = { _, _ in
            true
        }
        
        let applicationLauncher = ApplicationLaunchingMock()
        applicationLauncher.openHandler = { _, _, completion in
            completion?(true)
        }
        
        let provider = AuthorizationCodeAuthProvider(
            shouldExchangeAuthCode: true,
            configurationProvider: configurationProvider,
            applicationLauncher: applicationLauncher,
            networkProvider: networkProvider
        )
        
        provider.execute(
            authDestination: .native(appPriority: [.rides]),
            completion: { result in }
        )
        
        let url = URL(string: "test://app?code=123")!
        _ = provider.handle(response: url)
        
        XCTAssertTrue(hasCalledTokenRequest)
    }
    
    func test_nativeAuth_noTokenExchange_doesNotTriggerTokenRequest() {
        
        var hasCalledTokenRequest = false
        
        let networkProvider = NetworkProvidingMock()
        networkProvider.executeHandler = { request, _ in
            if request is TokenRequest {
                hasCalledTokenRequest = true
            }
        }
        
        configurationProvider.isInstalledHandler = { _, _ in
            true
        }
        
        let applicationLauncher = ApplicationLaunchingMock()
        applicationLauncher.openHandler = { _, _, completion in
            completion?(true)
        }
        
        let provider = AuthorizationCodeAuthProvider(
            configurationProvider: configurationProvider,
            applicationLauncher: applicationLauncher,
            networkProvider: networkProvider
        )
        
        provider.execute(
            authDestination: .native(appPriority: [.rides]),
            completion: { result in }
        )
        
        let url = URL(string: "test://app?code=123")!
        _ = provider.handle(response: url)
        
        XCTAssertFalse(hasCalledTokenRequest)
    }
    
    func test_nativeAuth_tokenExchange() {
        
        let token = Token(
            accessToken: "123",
            tokenType: "test_token"
        )
        
        let networkProvider = NetworkProvidingMock()
        networkProvider.executeHandler = { request, completion in
            if request is TokenRequest {
                let completion = completion as! (Result<TokenRequest.Response, UberAuthError>) -> ()
                completion(.success(token))
            }
            else if request is ParRequest {
                let completion = completion as! (Result<ParRequest.Response, UberAuthError>) -> ()
                completion(.success(Par(requestURI: nil, expiresIn: .now)))
            }
        }
        
        configurationProvider.isInstalledHandler = { _, _ in
            true
        }
        
        let applicationLauncher = ApplicationLaunchingMock()
        applicationLauncher.openHandler = { _, _, completion in
            completion?(true)
        }
        
        let provider = AuthorizationCodeAuthProvider(
            shouldExchangeAuthCode: true, 
            configurationProvider: configurationProvider,
            applicationLauncher: applicationLauncher,
            networkProvider: networkProvider
        )
        
        let expectation = XCTestExpectation()
        
        provider.execute(
            authDestination: .native(appPriority: [.rides]),
            completion: { result in
                expectation.fulfill()
                
                switch result {
                case .failure:
                    XCTFail()
                case .success(let client):
                    XCTAssertEqual(
                        client,
                        Client(
                            accessToken: "123",
                            tokenType: "test_token",
                            scope: []
                        )
                    )
                }
            }
        )
        
        let url = URL(string: "test://app?code=123")!
        _ = provider.handle(response: url)
        
        wait(for: [expectation], timeout: 0.1)
    }
}

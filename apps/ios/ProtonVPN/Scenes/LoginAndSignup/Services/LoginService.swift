//
//  LoginService.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 20.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import ProtonCore_DataModel
import ProtonCore_Login
import ProtonCore_LoginUI
import ProtonCore_Networking
import ProtonCore_Payments

protocol LoginServiceFactory: AnyObject {
    func makeLoginService() -> LoginService
}

enum SilengLoginResult {
    case loggedIn
    case notLoggedIn
}

protocol LoginServiceDelegate: AnyObject {
    func userDidLogIn()
    func usedDidSignUp(onboardingShowFirstConnection: Bool)
}

protocol LoginService: AnyObject {
    var delegate: LoginServiceDelegate? { get set }

    func attemptSilentLogIn(completion: @escaping (SilengLoginResult) -> Void)
    func showWelcome()
}

// MARK: CoreLoginService

final class CoreLoginService {
    typealias Factory = AppSessionManagerFactory
        & AppSessionRefresherFactory
        & WindowServiceFactory
        & CoreAlertServiceFactory
        & NetworkingDelegateFactory
        & PropertiesManagerFactory
        & NetworkingFactory
        & DoHVPNFactory
        & CoreApiServiceFactory

    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let windowService: WindowService
    private let alertService: AlertService
    private let networkingDelegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let networking: Networking
    private let propertiesManager: PropertiesManagerProtocol
    private let doh: DoHVPN
    private let coreApiService: CoreApiService

    private var login: LoginAndSignupInterface?

    weak var delegate: LoginServiceDelegate?

    init(factory: Factory) {
        appSessionManager = factory.makeAppSessionManager()
        appSessionRefresher = factory.makeAppSessionRefresher()
        windowService = factory.makeWindowService()
        alertService = factory.makeCoreAlertService()
        networkingDelegate = factory.makeNetworkingDelegate()
        propertiesManager = factory.makePropertiesManager()
        networking = factory.makeNetworking()
        doh = factory.makeDoHVPN()
        coreApiService = factory.makeCoreApiService()
    }

    private func show() {
        let signupAvailability = SignupAvailability.available(parameters: SignupParameters(passwordRestrictions: SignupPasswordRestrictions.default, summaryScreenVariant: SummaryScreenVariant.noSummaryScreen))
        let login = LoginAndSignup(appName: "ProtonVPN", clientApp: ClientApp.vpn, doh: doh, apiServiceDelegate: networking, forceUpgradeDelegate: networkingDelegate, minimumAccountType: AccountType.username, isCloseButtonAvailable: false, paymentsAvailability: PaymentsAvailability.notAvailable, signupAvailability: signupAvailability)
        self.login = login

        var onboardingShowFirstConnection = true
        let finishFlow = WorkBeforeFlow(stepName: LocalizedString.loginFetchVpnData) { [weak self] (data: LoginData, completion: @escaping (Result<Void, Error>) -> Void) -> Void in
            // attempt to use the login data to log in the app
            let authCredentials = AuthCredentials(data)
            self?.appSessionManager.finishLogin(authCredentials: authCredentials) { [weak self] result in
                switch result {
                case .success:
                    self?.coreApiService.getApiFeature(feature: .onboardingShowFirstConnection) { (result: Result<Bool, Error>) in
                        switch result {
                        case let .success(flag):
                            onboardingShowFirstConnection = flag
                            completion(.success(()))
                        case let .failure(error):
                            log.error("Failed to get onboardingShowFirstConnection flag, using default value", category: .app, metadata: ["error": "\(error)"])
                            completion(.success(()))
                        }
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }

        let variant = WelcomeScreenVariant.vpn(WelcomeScreenTexts(headline: LocalizedString.welcomeHeadline, body: LocalizedString.welcomeBody))
        let welcomeViewController = login.welcomeScreenForPresentingFlow(variant: variant, username: nil, performBeforeFlow: finishFlow, customErrorPresenter: self) { [weak self] (result: LoginResult) -> Void in
            switch result {
            case .dismissed:
                log.error("Dismissing the Welcome screen without login or signup should not be possible", category: .app)
            case .loggedIn:
                self?.delegate?.userDidLogIn()
            case .signedUp:
                self?.delegate?.usedDidSignUp(onboardingShowFirstConnection: onboardingShowFirstConnection)
            }

            self?.login = nil
        }

        windowService.show(viewController: welcomeViewController)
    }
}

// MARK: LoginErrorPresenter
extension CoreLoginService: LoginErrorPresenter {
    func willPresentError(error: LoginError, from: UIViewController) -> Bool {
        switch error {
        case .generic(_, _, ProtonVpnError.subuserWithoutSessions):
            alertService.push(alert: SubuserWithoutConnectionsAlert())
            return true
        default:
            return false
        }
    }

    func willPresentError(error: SignupError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: AvailabilityError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: SetUsernameError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: CreateAddressError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: CreateAddressKeysError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: StoreKitManagerErrors, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: ResponseError, from: UIViewController) -> Bool {
        return false
    }

    func willPresentError(error: Error, from: UIViewController) -> Bool {
        return false
    }
}

// MARK: LoginService

extension CoreLoginService: LoginService {
    func attemptSilentLogIn(completion: @escaping (SilengLoginResult) -> Void) {
        if appSessionManager.loadDataWithoutFetching() {
            appSessionRefresher.refreshData()
        } else { // if no data is stored already, then show spinner and wait for data from the api
            appSessionManager.attemptSilentLogIn { [appSessionManager] result in
                switch result {
                case .success:
                    completion(.loggedIn)
                case .failure:
                    appSessionManager.loadDataWithoutLogin(success: {
                        completion(.notLoggedIn)
                    }, failure: { _ in
                        completion(.notLoggedIn)
                    })
                }
            }
        }

        if appSessionManager.sessionStatus == .established {
            completion(.loggedIn)
        }
    }

    func showWelcome() {
        #if !RELEASE
        showEnvironmentSelection()
        #else
        show()
        #endif
    }
}

// MARK: Environment selection

#if !RELEASE
extension CoreLoginService: EnvironmentsViewControllerDelegate {
    private func showEnvironmentSelection() {
        let environmentsViewController = UIStoryboard(name: "Environments", bundle: nil).instantiateViewController(withIdentifier: "EnvironmentsViewController") as! EnvironmentsViewController
        environmentsViewController.propertiesManager = propertiesManager
        environmentsViewController.doh = doh
        environmentsViewController.delegate = self
        windowService.show(viewController: UINavigationController(rootViewController: environmentsViewController))
    }

    func userDidSelectContinue() {
        show()
    }
}
#endif

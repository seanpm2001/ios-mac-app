//
//  NewLoginTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_TestingToolkit

class LoginTests: ProtonVPNUITests {
    
    let mainRobot = MainRobot()
    let loginRobot = LoginRobot()
    let needHelpRobot = NeedHelpRobot()
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        changeEnvToProdIfNeeded()
        useAndContinueTap()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testLoginWithIncorrectCredentials() {
        
        let username = "wrong_username"
        let userpassword = "wrong_password"
            
        loginRobot
            .loginWrongUser(username, userpassword)
            .signIn(robot: LoginRobot.self)
            .verify.incorrectCredentialsErrorDialog()
    }
    
    func testLoginWithCorrectCredentials() {
        
        let credentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials", withExtension: "plist")!)
        
        for credential in credentials {
            login(withCredentials: credential)
            logoutIfNeeded()
            openLoginScreen()
        }
    }
    
    func testLoginAsSubuserWithNoConnectionsAssigned () {
        
        let subusercredentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "subusercredentials", withExtension: "plist")!)

        loginRobot
            .loginAsUser(subusercredentials[0])
            .signIn(robot: LoginRobot.self)
            .verify.assignVPNConnectionErrorIsShown()
            .verify.loginScreenIsShown()
    }
    
    func testLoginWithTwoPassUser() {
        loginAsTwoPassUser()
    }
    
    func testLoginAsTwoFa() {
        let twofausercredentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "twofausercredentials", withExtension: "plist")!)
        
        loginRobot
            .loginAsUser(twofausercredentials[0])
            .signIn(robot: TwoFaRobot.self)
            .fillTwoFACode(code: generateCodeFor2FAUser(ObfuscatedConstants.twoFASecurityKey))
            .confirm2FA(robot: MainRobot.self)
        correctUserIsLogedIn(twofausercredentials[0])
    }
    
    func testLoginWithTwoPassAnd2FAUser() {
        
        let twopasstwofausercredentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "twopasstwofausercredentials", withExtension: "plist")!)
        
        loginRobot
            .loginAsUser(twopasstwofausercredentials[0])
            .signIn(robot: TwoFaRobot.self)
            .fillTwoFACode(code: generateCodeFor2FAUser(ObfuscatedConstants.twoFAandTwoPassSecurityKey))
            .confirm2FA(robot: MainRobot.self)
        correctUserIsLogedIn(twopasstwofausercredentials[0])
    }
    
    func testNeedHelpClosed() {
        
        loginRobot
            .needHelp()
            .needHelpOptionsDisplayed()
            .closeNeedHelpScreen()
            .verify.loginScreenIsShown()
    }
}

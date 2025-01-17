//
//  ProtocolsListRobot.swift
//  ProtonVPNUITests
//
//  Created by Marc Flores on 31.08.21.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest
import XCTest

fileprivate let smartButton = "Smart"
fileprivate let settingsButton = "Settings back btn"
fileprivate let ikeButton = "IKEv2"

class ProtocolsListRobot: CoreElements {
    
    func ikeProtocolOn() -> ProtocolsListRobot {
        cell(ikeButton).tap()
        return ProtocolsListRobot()
    }

    func smartProtocolOn() -> ProtocolsListRobot {
        cell(smartButton).tap()
        return ProtocolsListRobot()
    }
    
    @discardableResult
    func returnToSettings() -> SettingsRobot {
        button(settingsButton).tap()
        return SettingsRobot()
    }
    
    /// Choose protocol from the protocol list
    /// - Precondition: Default protocol is Smart
    func protocolOn(_ protocolVia: String) -> ProtocolsListRobot {
         cell(protocolVia).tap()
         return ProtocolsListRobot()
     }
}

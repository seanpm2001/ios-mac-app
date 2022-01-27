//
//  Created on 2022-01-26.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import XCTest

fileprivate let establishConnectionTitle = "Establish your first connection"
fileprivate let establishConnectionDescription = "We will connect you to the fastest and most stable server depending on your location."
fileprivate let connectNowButton = "Connect now"
fileprivate let accessButton = "Access all countries with PLUS"
fileprivate let skipButton = "Skip"
fileprivate let connectionTitle = "Congratulations"
fileprivate let connectionDescription = "Your connection is protected and you’re ready to browse the web."
fileprivate let connectedTo = "Connected to:"
fileprivate let continueButton = "Continue"
fileprivate let getPlusButton = "Get Plus"

class OnboardingConnectionRobot {
    
    func connectNow() -> OnboardingConnectionRobot {
        app.buttons[connectNowButton].tap()
        return OnboardingConnectionRobot()
    }

    func accessAllCountries() -> OnboardingConnectionRobot {
        app.buttons[accessButton].tap()
        return OnboardingConnectionRobot()
    }
    
    func nextStepA() -> OnboardingPaymentRobot {
        app.buttons[continueButton].tap()
        return OnboardingPaymentRobot()
    }
    
    func nextStepB() -> OnboardingMainRobot {
        app.buttons[continueButton].tap()
        return OnboardingMainRobot()
    }
    
    public let verify = Verify()
    
    class Verify {
        
        func establichConnectionScreenIsShown() -> OnboardingConnectionRobot {
            XCTAssertTrue(app.staticTexts[establishConnectionTitle].exists)
            XCTAssertTrue(app.staticTexts[establishConnectionDescription].exists)
            XCTAssertTrue(app.buttons[connectNowButton].isEnabled)
            XCTAssertTrue(app.buttons[skipButton].firstMatch.isEnabled)
            XCTAssertTrue(app.buttons[accessButton].isEnabled)
            return OnboardingConnectionRobot()
        }
        
        func connectionScreenIsShown() -> OnboardingConnectionRobot {
            XCTAssert(app.staticTexts[connectionTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[connectionDescription].exists)
            XCTAssertTrue(app.staticTexts[connectedTo].exists)
            XCTAssertTrue(app.buttons[continueButton].isEnabled)
            return OnboardingConnectionRobot()
        }
    }
}
//
//  Created on 15.12.2021.
//
//  Copyright (c) 2021 Proton AG
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

import Foundation
import AppKit
import SwiftUI

public protocol BugReportCreatorFactory {
    func makeBugReportCreator() -> BugReportCreator
}

public protocol BugReportCreator {
    func createBugReportViewController(model: BugReportModel) -> NSViewController?
}

public final class macOSBugReportCreator: BugReportCreator {
    public init() { }

    public func createBugReportViewController(model: BugReportModel) -> NSViewController? {
        guard isNewBugReportEnabled, #available(macOS 10.15, *) else {
            return nil
        }

        return NSHostingController(rootView: BugReportView().frame(width: 600, height: 600, alignment: .center))
    }
}

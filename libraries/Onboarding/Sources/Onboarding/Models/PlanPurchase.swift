//
//  Created on 10.01.2022.
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

import Foundation
import UIKit

public final class PlanPurchase {
    public let onCreatePlanPurchaseViewController: (UIViewController) -> Void
    public let onPlanPurchased: () -> Void

    init(onCreatePlanPurchaseViewController: @escaping (UIViewController) -> Void, onPlanPurchased: @escaping () -> Void) {
        self.onCreatePlanPurchaseViewController = onCreatePlanPurchaseViewController
        self.onPlanPurchased = onPlanPurchased
    }
}
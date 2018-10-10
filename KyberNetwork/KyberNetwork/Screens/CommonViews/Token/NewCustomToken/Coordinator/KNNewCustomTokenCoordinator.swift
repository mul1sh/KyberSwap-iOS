// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class KNNewCustomTokenCoordinator: Coordinator {

  let navigationController: UINavigationController
  let storage: KNTokenStorage
  let token: ERC20Token?
  var coordinators: [Coordinator] = []

  lazy var rootViewController: KNNewCustomTokenViewController = {
    let controller = KNNewCustomTokenViewController(
      viewModel: KNNewCustomTokenViewModel(token: self.token),
      delegate: self
    )
    return controller
  }()

  init(
    navigationController: UINavigationController,
    storage: KNTokenStorage,
    token: ERC20Token?
    ) {
    self.navigationController = navigationController
    self.storage = storage
    self.token = token
  }

  func start() {
    let navController = UINavigationController(rootViewController: self.rootViewController)
    navController.applyStyle()
    self.navigationController.present(navController, animated: true, completion: nil)
  }

  func stop() {
    self.navigationController.popViewController(animated: true)
  }
}

extension KNNewCustomTokenCoordinator: KNNewCustomTokenViewControllerDelegate {
  func didCancel(in viewController: KNNewCustomTokenViewController) {
    self.stop()
  }

  func didAddToken(_ token: ERC20Token, in viewController: KNNewCustomTokenViewController) {
    self.storage.addCustom(token: token)
    KNNotificationUtil.postNotification(for: kTokenObjectListDidUpdateNotificationKey)
    self.stop()
  }
}
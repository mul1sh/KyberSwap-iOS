// Copyright SIX DAY LLC. All rights reserved.

import UIKit

protocol KConfirmSwapViewControllerDelegate: class {
  func kConfirmSwapViewController(_ controller: KConfirmSwapViewController, run event: KConfirmViewEvent)
}

class KConfirmSwapViewController: KNBaseViewController {

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var titleLabel: UILabel!

  @IBOutlet weak var fromAmountLabel: UILabel!
  @IBOutlet weak var toAmountLabel: UILabel!
  @IBOutlet weak var toTextLabel: UILabel!
  @IBOutlet weak var minAcceptableRateTextLabel: UILabel!
  @IBOutlet weak var transactionFeeTextLabel: UILabel!

  @IBOutlet weak var firstSeparatorView: UIView!

  @IBOutlet weak var expectedRateLabel: UILabel!
  @IBOutlet weak var minAcceptableRateLabel: UILabel!

  @IBOutlet weak var secondSeparatorView: UIView!

  @IBOutlet weak var transactionFeeETHLabel: UILabel!
  @IBOutlet weak var transactionFeeUSDLabel: UILabel!

  @IBOutlet weak var confirmButton: UIButton!
  @IBOutlet weak var cancelButton: UIButton!

  fileprivate var viewModel: KConfirmSwapViewModel
  weak var delegate: KConfirmSwapViewControllerDelegate?

  init(viewModel: KConfirmSwapViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KConfirmSwapViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupUI()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.firstSeparatorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
    self.secondSeparatorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)
  }

  fileprivate func setupUI() {
    let style = KNAppStyleType.current
    self.headerContainerView.backgroundColor = style.swapHeaderBackgroundColor

    self.titleLabel.text = self.viewModel.titleString

    self.fromAmountLabel.text = self.viewModel.leftAmountString
    self.toAmountLabel.text = self.viewModel.rightAmountString

    self.firstSeparatorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)

    self.expectedRateLabel.text = self.viewModel.displayEstimatedRate
    self.minAcceptableRateLabel.text = self.viewModel.minRateString

    self.transactionFeeETHLabel.text = self.viewModel.feeETHString
    self.transactionFeeUSDLabel.text = self.viewModel.feeUSDString

    self.secondSeparatorView.dashLine(width: 1.0, color: UIColor.Kyber.dashLine)

    self.confirmButton.rounded(radius: style.buttonRadius(for: self.confirmButton.frame.height))
    self.confirmButton.setTitle(
      NSLocalizedString("confirm", value: "Confirm", comment: ""),
      for: .normal
    )
    self.confirmButton.backgroundColor = style.swapActionButtonBackgroundColor
    self.cancelButton.setTitle(
      NSLocalizedString("cancel", value: "Cancel", comment: ""),
      for: .normal
    )

    self.toTextLabel.text = NSLocalizedString("transaction.to.text", value: "To", comment: "")
    self.minAcceptableRateTextLabel.text = NSLocalizedString("min.acceptable.rate", value: "Min Acceptable Rate", comment: "")
    self.transactionFeeTextLabel.text = NSLocalizedString("transaction.fee", value: "Transaction Fee", comment: "")
    self.view.layoutIfNeeded()
  }

  @IBAction func backButtonPressed(_ sender: Any) {
    self.delegate?.kConfirmSwapViewController(self, run: .cancel)
  }

  @IBAction func screenEdgePanGestureAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    if sender.state == .ended { self.delegate?.kConfirmSwapViewController(self, run: .cancel) }
  }

  @IBAction func confirmButtonPressed(_ sender: Any) {
    let event = KConfirmViewEvent.confirm(type: KNTransactionType.exchange(self.viewModel.transaction))
    self.updateActionButtonsSendingSwap()
    self.delegate?.kConfirmSwapViewController(self, run: event)
  }

  @IBAction func cancelButtonPressed(_ sender: Any) {
    self.delegate?.kConfirmSwapViewController(self, run: .cancel)
  }

  func updateActionButtonsSendingSwap() {
    self.confirmButton.backgroundColor = UIColor.clear
    self.confirmButton.setTitle("\(NSLocalizedString("in.progress", value: "In Progress", comment: "")) ...", for: .normal)
    self.confirmButton.setTitleColor(
      KNAppStyleType.current.swapActionButtonBackgroundColor,
      for: .normal
    )
    self.confirmButton.isEnabled = false
    self.cancelButton.isHidden = true
  }

  func resetActionButtons() {
    self.confirmButton.setTitle(
      NSLocalizedString("confirm", value: "Confirm", comment: ""),
      for: .normal
    )
    self.confirmButton.setTitleColor(UIColor.white, for: .normal)
    self.confirmButton.backgroundColor = KNAppStyleType.current.swapActionButtonBackgroundColor
    self.confirmButton.isEnabled = true
    self.cancelButton.isHidden = false
    self.cancelButton.setTitle(
      NSLocalizedString("cancel", value: "Cancel", comment: ""),
      for: .normal
    )
  }
}
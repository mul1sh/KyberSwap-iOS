// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import Result
import Moya

//swiftlint:disable file_length

enum KSwapViewEvent: Equatable {
  case searchToken(from: TokenObject, to: TokenObject, isSource: Bool)
  case estimateRate(from: TokenObject, to: TokenObject, amount: BigInt, hint: String, showError: Bool)
  case estimateComparedRate(from: TokenObject, to: TokenObject, hint: String) // compare to show warning
  case estimateGas(from: TokenObject, to: TokenObject, amount: BigInt, gasPrice: BigInt, hint: String)
  case setGasPrice(gasPrice: BigInt, gasLimit: BigInt)
  case validateRate(data: KNDraftExchangeTransaction)
  case swap(data: KNDraftExchangeTransaction)
  case showQRCode
  case quickTutorial(step: Int, pointsAndRadius: [(CGPoint, CGFloat)])
  case referencePrice(from: TokenObject, to: TokenObject)
  case swapHint(from: TokenObject, to: TokenObject, amount: String?)
  case openExplainPage

  static public func == (left: KSwapViewEvent, right: KSwapViewEvent) -> Bool {
    switch (left, right) {
    case let (.estimateGas(fromL, toL, amountL, gasPriceL, hintL), .estimateGas(fromR, toR, amountR, gasPriceR, hintR)):
      return fromL == fromR && toL == toR && amountL == amountR && gasPriceL == gasPriceR && hintL == hintR
    default:
      return false //Not implement
    }
  }
}

protocol KSwapViewControllerDelegate: class {
  func kSwapViewController(_ controller: KSwapViewController, run event: KSwapViewEvent)
  func kSwapViewController(_ controller: KSwapViewController, run event: KNBalanceTabHamburgerMenuViewEvent)
}

//swiftlint:disable type_body_length
class KSwapViewController: KNBaseViewController {

  fileprivate var isViewSetup: Bool = false
  fileprivate var isErrorMessageEnabled: Bool = false

  fileprivate var viewModel: KSwapViewModel
  weak var delegate: KSwapViewControllerDelegate?

  @IBOutlet weak var scrollContainerView: UIScrollView!

  @IBOutlet weak var headerContainerView: UIView!
  @IBOutlet weak var walletNameLabel: UILabel!
  @IBOutlet weak var dataContainerView: UIView!
  @IBOutlet weak var fromTokenButton: UIButton!

  @IBOutlet weak var hasPendingTxView: UIView!
  @IBOutlet weak var balanceTextLabel: UILabel! // "\(symbol) balance"
  @IBOutlet weak var balanceLabel: UILabel!
  @IBOutlet weak var toTokenButton: UIButton!

  @IBOutlet weak var fromAmountTextField: UITextField!
  @IBOutlet weak var equivalentUSDValueLabel: UILabel!
  @IBOutlet weak var toAmountTextField: UITextField!

  @IBOutlet weak var rateTextLabel: UILabel!
  @IBOutlet weak var exchangeRateLabel: UILabel!
  @IBOutlet weak var loadingRateIndicator: UIActivityIndicatorView!

  @IBOutlet weak var warningRateContainerView: UIView!
  @IBOutlet weak var warningRatePercent: UIButton!

  @IBOutlet weak var advancedSettingsView: KAdvancedSettingsView!
  @IBOutlet weak var heightConstraintForAdvacedSettingsView: NSLayoutConstraint!

  @IBOutlet weak var bottomPaddingConstraintForScrollView: NSLayoutConstraint!

  @IBOutlet weak var continueButton: UIButton!

  @IBOutlet var continueButtonBottomPaddingToContainerConstraint: NSLayoutConstraint!
  @IBOutlet var continueButtonBottomPaddingToSuggestViewConstraint: NSLayoutConstraint!

  @IBOutlet weak var swapSuggestionView: UIView!
  @IBOutlet weak var suggestionTextLabel: UILabel!

  @IBOutlet weak var firstSuggestButton: UIButton!
  @IBOutlet weak var firstSuggestType: UIButton!

  @IBOutlet weak var secondSuggestButton: UIButton!
  @IBOutlet weak var secondSuggestType: UIButton!

  @IBOutlet weak var thirdSuggestButton: UIButton!
  @IBOutlet weak var thirdSuggestType: UIButton!
  @IBOutlet weak var hasUnreadNotification: UIView!
  @IBOutlet weak var advanceSettingTopContraint: NSLayoutConstraint!
  @IBOutlet weak var gasWarningTextLabel: UILabel!
  @IBOutlet weak var gasWarningContainerView: UIView!
  @IBOutlet weak var gasWarningContainerViewHieghtContraint: NSLayoutConstraint!

  fileprivate var estRateTimer: Timer?
  fileprivate var estGasLimitTimer: Timer?
  fileprivate var previousCallEvent: KSwapViewEvent?
  fileprivate var previousCallTimeStamp: TimeInterval = 0

  lazy var hamburgerMenu: KNBalanceTabHamburgerMenuViewController = {
    let viewModel = KNBalanceTabHamburgerMenuViewModel(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.walletObject
    )
    let hamburgerVC = KNBalanceTabHamburgerMenuViewController(viewModel: viewModel)
    hamburgerVC.view.frame = self.view.bounds
    self.view.addSubview(hamburgerVC.view)
    self.addChildViewController(hamburgerVC)
    hamburgerVC.didMove(toParentViewController: self)
    hamburgerVC.delegate = self
    return hamburgerVC
  }()

  lazy var toolBar: KNCustomToolbar = {
    return KNCustomToolbar(
      leftBtnTitle: NSLocalizedString("swap.all", value: "Swap All", comment: ""),
      rightBtnTitle: NSLocalizedString("done", value: "Done", comment: ""),
      barTintColor: UIColor.Kyber.enygold,
      delegate: self)
  }()

  deinit {
    self.removeObserveNotification()
  }

  init(viewModel: KSwapViewModel) {
    self.viewModel = viewModel
    super.init(nibName: KSwapViewController.className, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.continueButton.applyGradient()

    self.addObserveNotifications()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !self.isViewSetup {
      self.isViewSetup = true
      self.setupUI()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.dataContainerView.addShadow(
      color: UIColor.black.withAlphaComponent(0.6),
      offset: CGSize(width: 0, height: 7),
      opacity: 0.32,
      radius: 32
    )
    self.advancedSettingsView.layoutSubviews()
    self.headerContainerView.removeSublayer(at: 0)
    self.headerContainerView.applyGradient(with: UIColor.Kyber.headerColors)
    self.continueButton.removeSublayer(at: 0)
    self.continueButton.applyGradient()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    self.isErrorMessageEnabled = true
    // start update est rate
    self.estRateTimer?.invalidate()
    self.updateEstimatedRate(showError: true, showLoading: true)
    self.updateReferencePrice()
    self.updateSwapHint(from: self.viewModel.from, to: self.viewModel.to, amount: self.viewModel.amountFromStringParameter)
    self.estRateTimer = Timer.scheduledTimer(
      withTimeInterval: KNLoadingInterval.seconds30,
      repeats: true,
      block: { [weak self] _ in
        guard let `self` = self else { return }
        self.updateEstimatedRate()
      }
    )

    // start update est gas limit
    self.estGasLimitTimer?.invalidate()
    self.updateEstimatedGasLimit()
    self.estGasLimitTimer = Timer.scheduledTimer(
      withTimeInterval: KNLoadingInterval.seconds60,
      repeats: true,
      block: { [weak self] _ in
        guard let `self` = self else { return }
        self.updateEstimatedGasLimit()
        self.updateSwapHint(from: self.viewModel.from, to: self.viewModel.to, amount: self.viewModel.amountFromStringParameter)
      }
    )

    self.updateExchangeRateField()

    self.loadSwapSuggestionIfNeeded()

    if NSObject.isNeedShowTutorial(for: Constants.isDoneShowQuickTutorialForSwapView) {
      self.viewModel.currentTutorialStep = 1
      self.showQuickTutorial()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    self.isErrorMessageEnabled = false
    self.view.endEditing(true)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.estRateTimer?.invalidate()
    self.estRateTimer = nil
    self.estGasLimitTimer?.invalidate()
    self.estGasLimitTimer = nil
  }

  fileprivate func setupUI() {
    self.bottomPaddingConstraintForScrollView.constant = self.bottomPaddingSafeArea()
    hasUnreadNotification.rounded(radius: hasUnreadNotification.frame.height / 2)
    self.walletNameLabel.text = self.viewModel.walletNameString
    self.setupTokensView()
    self.setupHamburgerMenu()
    self.setupAdvancedSettingsView()
    self.setupContinueButton()
    self.setupSwapSuggestionView()
    self.notificationDidUpdate(nil)
  }

  fileprivate func setupTokensView() {
    self.dataContainerView.rounded(radius: 4)

    self.fromTokenButton.titleLabel?.numberOfLines = 2
    self.fromTokenButton.titleLabel?.lineBreakMode = .byTruncatingTail
    self.toTokenButton.titleLabel?.numberOfLines = 2
    self.toTokenButton.titleLabel?.lineBreakMode = .byTruncatingTail

    self.fromAmountTextField.text = ""
    self.fromAmountTextField.adjustsFontSizeToFitWidth = true
    self.fromAmountTextField.inputAccessoryView = self.toolBar
    self.fromAmountTextField.delegate = self

    self.viewModel.updateAmount("", isSource: true)
    self.balanceTextLabel.text = self.viewModel.balanceTextString
    self.rateTextLabel.text = NSLocalizedString("rate", value: "Rate", comment: "").uppercased()

    self.toAmountTextField.text = ""
    self.toAmountTextField.adjustsFontSizeToFitWidth = true
    self.toAmountTextField.inputAccessoryView = self.toolBar
    self.toAmountTextField.delegate = self

    self.viewModel.updateAmount("", isSource: false)

    let tapBalanceGesture = UITapGestureRecognizer(target: self, action: #selector(self.balanceLabelTapped(_:)))
    self.balanceLabel.addGestureRecognizer(tapBalanceGesture)

    self.updateTokensView()
  }

  fileprivate func setupHamburgerMenu() {
    self.hasPendingTxView.rounded()
    self.hamburgerMenu.hideMenu(animated: false)
  }

  fileprivate func setupAdvancedSettingsView() {
    let isPromo = KNWalletPromoInfoStorage.shared.getDestWallet(from: self.viewModel.walletObject.address) != nil
    let viewModel = KAdvancedSettingsViewModel(hasMinRate: true, isPromo: isPromo, gasLimit: self.viewModel.estimateGasLimit)
    viewModel.updateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas,
      superFast: KNGasCoordinator.shared.superFastKNGas
    )
    viewModel.updateMinRateValue(self.viewModel.estimatedRateDouble, percent: self.viewModel.minRatePercent)
    viewModel.updateViewHidden(isHidden: true)
    viewModel.updatePairToken("\(self.viewModel.from.symbol)-\(self.viewModel.to.symbol)")
    self.advancedSettingsView.updateViewModel(viewModel)
    self.heightConstraintForAdvacedSettingsView.constant = self.advancedSettingsView.height
    self.advancedSettingsView.delegate = self
    self.advancedSettingsView.updateGasLimit(self.viewModel.estimateGasLimit)
    self.advancedSettingsView.updateIsUsingReverseRoutingStatus(value: true)
    self.viewModel.isUsingReverseRouting = true
    self.view.setNeedsUpdateConstraints()
    self.view.updateConstraints()
  }

  fileprivate func setupContinueButton() {
    let style = KNAppStyleType.current
    let radius = style.buttonRadius()
    self.continueButton.rounded(radius: radius)
    self.continueButton.setTitle(
      NSLocalizedString("Swap Now", value: "Swap Now", comment: ""),
      for: .normal
    )
  }

  // MARK: Swap Suggestion
  fileprivate func setupSwapSuggestionView() {
    self.suggestionTextLabel.text = "Suggestion".toBeLocalised()
    self.firstSuggestButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: 5.0
    )
    self.firstSuggestType.rounded(radius: self.firstSuggestType.frame.height / 2.0)
    self.secondSuggestButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: 5.0
    )
    self.secondSuggestType.rounded(radius: self.secondSuggestType.frame.height / 2.0)
    self.thirdSuggestButton.rounded(
      color: UIColor.Kyber.border,
      width: 1.0,
      radius: 5.0
    )
    self.thirdSuggestType.rounded(radius: self.thirdSuggestType.frame.height / 2.0)

    self.updateSwapSuggestionView()
  }

  fileprivate func updateSwapSuggestionView() {
    if self.viewModel.isSwapSuggestionShown {
      self.swapSuggestionView.isHidden = false
      self.continueButtonBottomPaddingToContainerConstraint.constant = 164.0
      self.continueButtonBottomPaddingToContainerConstraint.isActive = false
      self.continueButtonBottomPaddingToSuggestViewConstraint.isActive = true

      guard let suggestions = self.viewModel.swapSuggestion else { return }
      self.updateSwapSuggestionButtonWithData(suggestButton: self.firstSuggestButton, typeButton: self.firstSuggestType, data: suggestions[0])
      if suggestions.count > 1 {
        self.updateSwapSuggestionButtonWithData(suggestButton: self.secondSuggestButton, typeButton: self.secondSuggestType, data: suggestions[1])
      } else {
        self.updateSwapSuggestionButtonWithData(suggestButton: self.secondSuggestButton, typeButton: self.secondSuggestType, data: nil)
      }
      if suggestions.count > 2 {
        self.updateSwapSuggestionButtonWithData(suggestButton: self.thirdSuggestButton, typeButton: self.thirdSuggestType, data: suggestions[2])
      } else {
        self.updateSwapSuggestionButtonWithData(suggestButton: self.thirdSuggestButton, typeButton: self.thirdSuggestType, data: nil)
      }
    } else {
      self.swapSuggestionView.isHidden = true
      self.continueButtonBottomPaddingToContainerConstraint.constant = 32.0
      self.continueButtonBottomPaddingToContainerConstraint.isActive = true
      self.continueButtonBottomPaddingToSuggestViewConstraint.isActive = false
    }
    self.view.layoutIfNeeded()
  }

  fileprivate func updateSwapSuggestionButtonWithData(suggestButton: UIButton, typeButton: UIButton, data: JSONDictionary?) {
    guard let json = data else {
      suggestButton.isHidden = true
      typeButton.isHidden = true
      return
    }
    if let from = json["frm"] as? String, let to = json["to"] as? String {
      suggestButton.setTitle("\(from) ➞ \(to)", for: .normal)
      suggestButton.isHidden = false

      if let type = json["tags"] as? String {
        typeButton.setTitle(type, for: .normal)
        typeButton.isHidden = false
        if type == "trending" {
          typeButton.setImage(UIImage(named: "trending_icon"), for: .normal)
          typeButton.setTitleColor(UIColor(red: 250, green: 101, blue: 102), for: .normal)
        }
        if type == "best rate" {
          typeButton.setImage(UIImage(named: "best_rate_icon"), for: .normal)
          typeButton.setTitleColor(UIColor.Kyber.blueGreen, for: .normal)
        }
        if type == "promoted" {
          typeButton.setImage(UIImage(named: "promoted_icon"), for: .normal)
          typeButton.setTitleColor(UIColor.Kyber.shamrock, for: .normal)
        }
      } else {
        typeButton.isHidden = true
      }
    } else {
      suggestButton.isHidden = true
      typeButton.isHidden = true
    }
  }

  @IBAction func hamburgerMenuPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_hamburger_menu", customAttributes: nil)
    self.view.endEditing(true)
    self.hamburgerMenu.openMenu(animated: true)
  }

  @IBAction func fromTokenButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_token_select", customAttributes: nil)
    let event = KSwapViewEvent.searchToken(
      from: self.viewModel.from,
      to: self.viewModel.to,
      isSource: true
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  @IBAction func toTokenButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_token_select", customAttributes: nil)
    let event = KSwapViewEvent.searchToken(
      from: self.viewModel.from,
      to: self.viewModel.to,
      isSource: false
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  @IBAction func swapButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_swap_2_tokens", customAttributes: nil)
    if !self.viewModel.isFromTokenBtnEnabled { return }
    self.viewModel.swapTokens()
    self.fromAmountTextField.text = ""
    self.toAmountTextField.text = ""
    self.viewModel.updateAmount("", isSource: true)
    self.viewModel.updateAmount("", isSource: false)
    self.updateTokensView()
    self.updateEstimatedGasLimit()
    self.updateSwapHint(from: self.viewModel.from, to: self.viewModel.to, amount: nil)
    self.advancedSettingsView.updateIsUsingReverseRoutingStatus(value: true)
    self.viewModel.isUsingReverseRouting = true
  }

  @IBAction func warningRateButtonPressed(_ sender: Any) {
    guard let string = self.viewModel.differentRatePercentageDisplay else { return }
    let message = String(format: "There.is.a.difference.between.the.estimated.price".toBeLocalised(), string)
    self.showTopBannerView(
      with: "",
      message: message,
      icon: UIImage(named: "info_blue_icon"),
      time: 5.0
    )
  }

  @objc func prodCachedRateFailedToLoad(_ sender: Any?) {
    let event = KSwapViewEvent.estimateComparedRate(
      from: self.viewModel.from,
      to: self.viewModel.to,
      hint: self.viewModel.getHint(from: self.viewModel.from.address, to: self.viewModel.to.address)
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  /*
   Continue token pressed
   - check amount valid (> 0 and <= balance)
   - check rate is valie (not zero)
   - (Temp) either from or to must be ETH
   - send exchange tx to coordinator for preparing trade
   */
  @IBAction func continueButtonPressed(_ sender: UIButton) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_swap_tapped", customAttributes: nil)
    self.validateDataBeforeContinuing(hasCallValidateRate: false)
  }

  fileprivate func validateDataBeforeContinuing(hasCallValidateRate: Bool) {
    if self.showWarningDataInvalidIfNeeded(isConfirming: true) { return }
    let rate = self.viewModel.estRate ?? BigInt(0)
    let amount: BigInt = {
      if self.viewModel.isFocusingFromAmount {
        if self.viewModel.isSwapAllBalance {
          let balance = self.viewModel.balance?.value ?? BigInt(0)
          if !self.viewModel.from.isETH { return balance } // token, no need minus fee
          let fee = self.viewModel.allETHBalanceFee
          return max(BigInt(0), balance - fee)
        }
        return self.viewModel.amountFromBigInt
      }
      let expectedExchange: BigInt = {
        if rate.isZero { return rate }
        let amount = self.viewModel.amountToBigInt
        return amount * BigInt(10).power(self.viewModel.from.decimals) / rate
      }()
      return expectedExchange
    }()
    let exchange = KNDraftExchangeTransaction(
      from: self.viewModel.from,
      to: self.viewModel.to,
      amount: amount,
      maxDestAmount: BigInt(2).power(255),
      expectedRate: rate,
      minRate: self.viewModel.minRate,
      gasPrice: self.viewModel.gasPrice,
      gasLimit: self.viewModel.estimateGasLimit,
      expectedReceivedString: self.viewModel.amountTo,
      hint: self.viewModel.getHint(from: self.viewModel.from.address, to: self.viewModel.to.address)
    )
    if !hasCallValidateRate {
      self.delegate?.kSwapViewController(self, run: .validateRate(data: exchange))
    } else {
      self.delegate?.kSwapViewController(self, run: .swap(data: exchange))
    }
  }

  @IBAction func screenEdgePanGestureAction(_ sender: UIScreenEdgePanGestureRecognizer) {
    self.hamburgerMenu.gestureScreenEdgePanAction(sender)
  }

  @IBAction func swapSuggestionButtonPressed(_ sender: UIButton) {
    guard let suggestions = self.viewModel.swapSuggestion, suggestions.count > sender.tag else { return }
    let suggest = suggestions[sender.tag]
    guard let from = suggest["frm"] as? String,
      let fromToken = KNSupportedTokenStorage.shared.supportedTokens.first(where: { $0.symbol == from }),
      let to = suggest["to"] as? String,
      let toToken = KNSupportedTokenStorage.shared.supportedTokens.first(where: { $0.symbol == to }) else { return }
    // Update source and dest tokens
    self.coordinatorUpdateSelectedToken(fromToken, isSource: true, isWarningShown: false)
    self.coordinatorUpdateSelectedToken(toToken, isSource: false, isWarningShown: true)
    if self.viewModel.from != fromToken { return } // can not update from token, should be fromToken is disabled
    // Update source amount if needed
    guard let amount = suggest["amt"] as? Double else { return }
    guard let balance = self.viewModel.balances[fromToken.contract] else { return }

    // Computing available balance, in case ETH need to minus tx fee
    let availableBal: Double = {
      let bal = Double(balance.value) / pow(10.0, Double(fromToken.decimals))
      if fromToken.isETH {
        let fee = Double(self.viewModel.feeBigInt) / pow(10.0, 18.0)
        return max(0, bal - fee)
      }
      return bal
    }()

    let amountFrom = min(amount, availableBal)
    if amountFrom <= 0.0001 { return } // no need to update if amount is small to prevent showing warning
    let amountString = BigInt(amountFrom * pow(10.0, Double(fromToken.decimals))).string(
      decimals: fromToken.decimals,
      minFractionDigits: min(fromToken.decimals, 4),
      maxFractionDigits: min(fromToken.decimals, 4)
      ).removeGroupSeparator()

    // Update source amount data
    self.viewModel.updateFocusingField(true)
    self.fromAmountTextField.text = amountString
    self.viewModel.updateAmount(amountString, isSource: true)
    self.updateViewAmountDidChange()
    _ = self.showWarningDataInvalidIfNeeded()
  }

  fileprivate func updateFromAmountUIForSwapAllBalanceIfNeeded() {
    guard self.viewModel.isSwapAllBalance, self.viewModel.from.isETH else { return }
    self.fromAmountTextField.text = self.viewModel.allFromTokenBalanceString.removeGroupSeparator()
    self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true, forSwapAllETH: true)
    self.updateViewAmountDidChange(needUpdateEstRate: false)
  }

  @objc func keyboardSwapAllButtonPressed(_ sender: Any) {
    KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_swap_all", customAttributes: nil)
    self.view.endEditing(true)
    self.viewModel.updateFocusingField(true)
    self.fromAmountTextField.text = self.viewModel.allFromTokenBalanceString.removeGroupSeparator()
    self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true, forSwapAllETH: self.viewModel.from.isETH)
    self.updateTokensView()
    self.updateViewAmountDidChange()
    self.updateSwapHint(from: self.viewModel.from, to: self.viewModel.to, amount: self.viewModel.amountFromStringParameter)
    if sender as? KSwapViewController != self {
      if self.viewModel.from.isETH {
        self.showSuccessTopBannerMessage(
          with: "",
          message: NSLocalizedString("a.small.amount.of.eth.is.used.for.transaction.fee", value: "A small amount of ETH will be used for transaction fee", comment: ""),
          time: 1.5
        )
      }
    }

    self.viewModel.isSwapAllBalance = true
    self.view.layoutIfNeeded()
  }

  @objc func keyboardDoneButtonPressed(_ sender: Any) {
    self.view.endEditing(true)
    self.view.layoutIfNeeded()
  }

  func coordinatorUpdateGasPriceCached() {
    self.viewModel.updateSelectedGasPriceType(self.viewModel.selectedGasPriceType)
    self.updateAdvancedSettingsView()
    self.updateFromAmountUIForSwapAllBalanceIfNeeded()
    self.updateGasWarningUI()
  }

  fileprivate func updateEstimatedRate(showError: Bool = false, showLoading: Bool = false) {
    self.loadingRateIndicator.startAnimating()
    if showLoading { self.loadingRateIndicator.isHidden = false }
    let event = KSwapViewEvent.estimateRate(
      from: self.viewModel.from,
      to: self.viewModel.to,
      amount: self.viewModel.amountToEstimate,
      hint: self.viewModel.getHint(from: self.viewModel.from.address, to: self.viewModel.to.address),
      showError: showError
    )
    self.delegate?.kSwapViewController(self, run: event)
  }

  fileprivate func updateReferencePrice() {
    KNRateCoordinator.shared.currentSymPair = (self.viewModel.from.symbol, self.viewModel.to.symbol)
    let event = KSwapViewEvent.referencePrice(from: self.viewModel.from, to: self.viewModel.to)
    self.delegate?.kSwapViewController(self, run: event)
  }

  fileprivate func updateSwapHint(from: TokenObject, to: TokenObject, amount: String?) {
    let event = KSwapViewEvent.swapHint(from: from, to: to, amount: amount)
    self.delegate?.kSwapViewController(self, run: event)
  }

  @IBAction func notificationMenuButtonPressed(_ sender: UIButton) {
    self.delegate?.kSwapViewController(self, run: .selectNotifications)
  }

  fileprivate func updateEstimatedGasLimit() {
    let event = KSwapViewEvent.estimateGas(
      from: self.viewModel.from,
      to: self.viewModel.to,
      amount: self.viewModel.amountToEstimate,
      gasPrice: self.viewModel.gasPrice,
      hint: self.viewModel.getHint(from: self.viewModel.from.address, to: self.viewModel.to.address)
    )
    //Dismiss event call if the same parameter call within 5 sec
    if let previousEvent = self.previousCallEvent, previousEvent == event, Date().timeIntervalSince1970 - self.previousCallTimeStamp < 5 {
      return
    }
    self.previousCallEvent = event
    self.previousCallTimeStamp = Date().timeIntervalSince1970
    self.delegate?.kSwapViewController(self, run: event)
  }
  /*
   Return true if data is invalid and a warning message is shown,
   false otherwise
  */
  fileprivate func showWarningDataInvalidIfNeeded(isConfirming: Bool = false) -> Bool {
    if !isConfirming && !self.isErrorMessageEnabled || !self.hamburgerMenu.view.isHidden { return false }
    if !isConfirming && (self.fromAmountTextField.isEditing || self.toAmountTextField.isEditing) { return false }
    guard self.viewModel.from != self.viewModel.to else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("unsupported", value: "Unsupported", comment: ""),
        message: NSLocalizedString("can.not.swap.same.token", value: "Can not swap the same token", comment: ""),
        time: 1.5
      )
      KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "can.not.swap.same.token".toBeLocalised()])
      return true
    }
    guard !self.viewModel.amountFrom.isEmpty else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.input", value: "Invalid input", comment: ""),
        message: NSLocalizedString("please.enter.an.amount.to.continue", value: "Please enter an amount to continue", comment: "")
      )
      KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "please.enter.an.amount.to.continue".toBeLocalised()])
      return true
    }
    if self.viewModel.isPairUnderMaintenance {
      self.showWarningTopBannerMessage(
        with: "",
        message: NSLocalizedString("This token pair is temporarily under maintenance", value: "This token pair is temporarily under maintenance", comment: ""),
        time: 3
      ) {
        self.delegate?.kSwapViewController(self, run: .openExplainPage)
      }
      KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "This token pair is temporarily under maintenance".toBeLocalised()])
      return true
    }
    if self.viewModel.estRate?.isZero == true {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("amount.too.big", value: "Amount too big", comment: ""),
        message: NSLocalizedString("can.not.handle.your.amount", value: "Can not handle your amount", comment: ""),
        time: 3
      ) {
        self.delegate?.kSwapViewController(self, run: .openExplainPage)
      }
      KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "can.not.handle.your.amount".toBeLocalised()])
      return true
    }
    guard self.viewModel.isBalanceEnough else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("amount.too.big", value: "Amount too big", comment: ""),
        message: NSLocalizedString("balance.not.enough.to.make.transaction", value: "Balance is not enough to make the transaction.", comment: "")
      )
      KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "balance.not.enough.to.make.transaction".toBeLocalised()])
      return true
    }
    guard !self.viewModel.isAmountTooSmall else {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("invalid.amount", value: "Invalid amount", comment: ""),
        message: NSLocalizedString("amount.too.small.to.perform.swap", value: "Amount too small to perform swap, minimum equivalent to 0.001 ETH", comment: "")
      )
      KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "amount.too.small.to.perform.swap".toBeLocalised()])
      return true
    }
    if isConfirming {
      guard self.viewModel.isHavingEnoughETHForFee else {
        let fee = self.viewModel.feeBigInt
        self.showWarningTopBannerMessage(
          with: NSLocalizedString("Insufficient ETH for transaction", value: "Insufficient ETH for transaction", comment: ""),
          message: String(format: "Deposit more ETH or click Advanced to lower GAS fee".toBeLocalised(), fee.shortString(units: .ether, maxFractionDigits: 6))
        )
        KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "Deposit more ETH or click Advanced to lower GAS fee".toBeLocalised()])
        return true
      }
      guard self.viewModel.isSlippageRateValid else {
        self.showWarningTopBannerMessage(
          with: NSLocalizedString("invalid.amount", value: "Invalid amount", comment: ""),
          message: NSLocalizedString("can.not.handle.your.amount", value: "Can not handle your amount", comment: ""),
          time: 3
        ) {
          self.delegate?.kSwapViewController(self, run: .openExplainPage)
        }
        KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "can.not.handle.your.amount".toBeLocalised()])
        return true
      }
      guard self.advancedSettingsView.isMinRateValid else {
        if self.advancedSettingsView.viewModel != nil && self.advancedSettingsView.viewModel.isViewHidden {
          self.advancedSettingsView.displayViewButtonPressed(self)
        }
        self.advancedSettingsView.updateMinRateCustomErrorShown(true)
        self.showWarningTopBannerMessage(
          with: "",
          message: "Please enter a value between 0 and 100 for custom field in advanced settings view".toBeLocalised()
        )
        KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "Please enter a value between 0 and 100 for custom field in advanced settings view".toBeLocalised()])
        return true
      }
      guard self.viewModel.estRate != nil, self.viewModel.estRate?.isZero == false else {
        self.showWarningTopBannerMessage(
          with: NSLocalizedString("rate.might.change", value: "Rate might change", comment: ""),
          message: NSLocalizedString("please.wait.for.expected.rate.updated", value: "Please wait for expected rate to be updated", comment: "")
        )
        KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_error", customAttributes: ["error_text": "please.wait.for.expected.rate.updated".toBeLocalised()])
        return true
      }
    }
    return false
  }

  // Swap suggestion
  fileprivate func loadSwapSuggestionIfNeeded() {
    if self.viewModel.swapSuggestion != nil { return }
    let provider = MoyaProvider<KNTrackerService>()
    var tokens: JSONDictionary = [:]
    KNSupportedTokenStorage.shared.supportedTokens.forEach { token in
      if let bal = self.viewModel.balances[token.contract], !bal.value.isZero {
        tokens[token.contract] = Double(bal.value) / pow(10.0, Double(token.decimals))
      }
    }
    let address = self.viewModel.walletObject.address
    DispatchQueue.global().async {
      provider.request(.swapSuggestion(address: address, tokens: tokens)) { [weak self] result in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          switch result {
          case .success(let data):
            do {
              let json = try data.mapJSON(failsOnEmptyData: false) as? JSONDictionary ?? [:]
              let keys = json.keys.sorted(by: { return $0 < $1 })
              self.viewModel.swapSuggestion = keys.map({ return json[$0] as? JSONDictionary ?? [:] })
              self.updateSwapSuggestionView()
            } catch { }
          case .failure(let error):
            print("Error Swap Suggestion: \(error.prettyError)")
          }
        }
      }
    }
  }

  @objc func notificationDidUpdate(_ sender: Any?) {
    let numUnread: Int = {
      if IEOUserStorage.shared.user == nil { return 0 }
      return KNNotificationCoordinator.shared.numberUnread
    }()
    self.update(notificationsCount: numUnread)
  }

  @objc func notificationReachabilityDidUpdate(notification: Notification) {
    guard self.isViewSetup else {
      return
    }
    self.updateSwapHint(from: self.viewModel.from, to: self.viewModel.to, amount: self.viewModel.amountFromStringParameter)
  }

  func update(notificationsCount: Int) {
    self.hasUnreadNotification.isHidden = notificationsCount == 0
  }

  func showQuickTutorial() {
    var pointsAndRadius: [(CGPoint, CGFloat)] = []
    switch self.viewModel.currentTutorialStep {
    case 1:
      pointsAndRadius = [(CGPoint(x: 92, y: self.dataContainerView.frame.midY), 109)]
    case 2:
      pointsAndRadius = [(CGPoint(x: self.view.frame.size.width - 92, y: self.dataContainerView.frame.midY), 108)]
    case 3:
      pointsAndRadius = [(CGPoint(x: self.scrollContainerView.frame.midX - 60, y: self.view.frame.height - self.scrollContainerView.frame.size.height / 2), 167)]
      self.advancedSettingsView.displayViewButtonPressed(self)
    default:
      break
    }
    let event = KSwapViewEvent.quickTutorial(step: self.viewModel.currentTutorialStep, pointsAndRadius: pointsAndRadius)
    self.delegate?.kSwapViewController(self, run: event)
  }

  override func quickTutorialNextAction() {
    self.dismissTutorialOverlayer()
    if self.viewModel.currentTutorialStep == 3 {
      self.advancedSettingsView.displayViewButtonPressed(self)
      NSObject.updateDoneTutorial(for: Constants.isDoneShowQuickTutorialForSwapView)
      KNCrashlyticsUtil.logCustomEvent(withName: "tut_swap_got_it_button_tapped", customAttributes: nil)
      return
    }
    self.viewModel.currentTutorialStep += 1
    self.showQuickTutorial()
    KNCrashlyticsUtil.logCustomEvent(withName: "tut_swap_next_button_tapped", customAttributes: nil)
  }

  func isNeedToReloadGasLimit() -> Bool {
    return Date().timeIntervalSince1970 - self.viewModel.lastSuccessLoadGasLimitTimeStamp > KNLoadingInterval.seconds60
  }

  @IBAction func closeGasWarningPopupTapped(_ sender: UIButton) {
    self.viewModel.saveCloseGasWarningState()
    self.updateGasWarningUI()
  }
}

// MARK: Update UIs
extension KSwapViewController {
  /*
   Update tokens view when either from or to tokens changed
   - updatedFrom: true if from token is changed
   - updatedTo: true if to token is changed
   */
  func updateTokensView(updatedFrom: Bool = true, updatedTo: Bool = true) {
    if updatedFrom {
      self.fromTokenButton.setAttributedTitle(
        self.viewModel.tokenButtonAttributedText(isSource: true),
        for: .normal
      )
      self.fromTokenButton.setTokenImage(
        token: self.viewModel.from,
        size: self.viewModel.defaultTokenIconImg?.size
      )
      self.balanceTextLabel.text = self.viewModel.balanceTextString
    }
    if updatedTo {
      self.toTokenButton.setAttributedTitle(
        self.viewModel.tokenButtonAttributedText(isSource: false),
        for: .normal
      )
      self.toTokenButton.setTokenImage(
        token: self.viewModel.to,
        size: self.viewModel.defaultTokenIconImg?.size
      )
    }
    self.viewModel.updateEstimatedRateFromCachedIfNeeded()
    // call update est rate from node
    self.updateEstimatedRate(showError: updatedFrom || updatedTo, showLoading: updatedFrom || updatedTo)
    self.updateReferencePrice()
    self.balanceLabel.text = self.viewModel.balanceText

    self.updateExchangeRateField()

    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    }
    if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.updateAdvancedSettingsView()

    // update tokens button in case promo wallet
    self.toTokenButton.isEnabled = self.viewModel.isToTokenBtnEnabled
    self.fromTokenButton.isEnabled = self.viewModel.isFromTokenBtnEnabled

    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.view.layoutIfNeeded()
  }

  fileprivate func updateExchangeRateField() {
    self.exchangeRateLabel.text = self.viewModel.exchangeRateText
    let warningRate: String? = self.viewModel.differentRatePercentageDisplay
    self.warningRateContainerView.isHidden = warningRate == nil
    self.warningRatePercent.setTitle(warningRate, for: .normal)
  }

  fileprivate func updateAdvancedSettingsView() {
    let rate = self.viewModel.estimatedRateDouble
    let percent = self.viewModel.minRatePercent
    self.advancedSettingsView.updatePairToken("\(self.viewModel.from.symbol)-\(self.viewModel.to.symbol)")
    self.advancedSettingsView.updateMinRate(rate, percent: percent)

    self.advancedSettingsView.updateGasPrices(
      fast: KNGasCoordinator.shared.fastKNGas,
      medium: KNGasCoordinator.shared.standardKNGas,
      slow: KNGasCoordinator.shared.lowKNGas,
      superFast: KNGasCoordinator.shared.superFastKNGas
    )
    self.view.layoutIfNeeded()
  }

  fileprivate func updateGasWarningUI() {
    var currentGasPrice = KNGasCoordinator.shared.standardKNGas
    switch self.viewModel.selectedGasPriceType {
    case .superFast:
      currentGasPrice = KNGasCoordinator.shared.superFastKNGas
    case .fast:
      currentGasPrice = KNGasCoordinator.shared.fastKNGas
    case .medium:
      currentGasPrice = KNGasCoordinator.shared.standardKNGas
    case .slow:
      currentGasPrice = KNGasCoordinator.shared.lowKNGas
    }
    var limit = UserDefaults.standard.double(forKey: Constants.gasWarningValueKey)
    if limit <= 0 { limit = 200 }
    let limitBigInit = EtherNumberFormatter.full.number(from: limit.description, units: UnitConfiguration.gasPriceUnit)!
    let isShowWarning = (currentGasPrice > limitBigInit) && !self.viewModel.isCloseGasWarningPopup
    self.advanceSettingTopContraint.constant = isShowWarning ? 86 : 24
    self.gasWarningContainerView.isHidden = !isShowWarning
    if isShowWarning {
      let estFee = currentGasPrice * self.viewModel.estimateGasLimit
      let feeString: String = estFee.displayRate(decimals: 18)
      let warningText = String(format: "High network congestion. Please double check gas fee (~%@ ETH) before confirmation.".toBeLocalised(), feeString)
      self.gasWarningTextLabel.text = warningText
    }
  }

  @objc func balanceLabelTapped(_ sender: Any) {
    self.keyboardSwapAllButtonPressed(sender)
  }
}

extension KSwapViewController {
  fileprivate func addObserveNotifications() {
    let name = Notification.Name(kProdCachedRateFailedToLoadNotiKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.prodCachedRateFailedToLoad(_:)),
      name: name,
      object: nil
    )

    let nameUpdateListNotificationKey = Notification.Name(kUpdateListNotificationsKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.notificationDidUpdate(_:)),
      name: nameUpdateListNotificationKey,
      object: nil
    )
    let notiReachabilityName = Notification.Name(rawValue: KNReachability.kNetworkReachableNotificationKey)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.notificationReachabilityDidUpdate(notification:)),
      name: notiReachabilityName,
      object: nil
    )
  }

  fileprivate func removeObserveNotification() {
    let name = Notification.Name(kProdCachedRateFailedToLoadNotiKey)
    NotificationCenter.default.removeObserver(self, name: name, object: nil)

    let nameUpdateListNotificationKey = Notification.Name(kUpdateListNotificationsKey)
    NotificationCenter.default.removeObserver(self, name: nameUpdateListNotificationKey, object: nil)

    let notiReachabilityName = Notification.Name(rawValue: KNReachability.kNetworkReachableNotificationKey)
    NotificationCenter.default.removeObserver(self, name: notiReachabilityName, object: nil)
  }
}

// MARK: Update from coordinator
extension KSwapViewController {
  /*
   Update new session when current wallet is changed, update all UIs
   */
  func coordinatorUpdateNewSession(wallet: Wallet) {
    self.viewModel.updateWallet(wallet)
    self.walletNameLabel.text = self.viewModel.walletNameString
    self.fromAmountTextField.text = ""
    self.toAmountTextField.text = ""
    self.viewModel.updateAmount("", isSource: true)
    self.viewModel.updateAmount("", isSource: false)
    self.updateTokensView()
    self.updateViewAmountDidChange()
    self.updateAdvancedSettingsView()
    self.updateGasWarningUI()
    let isPromo = KNWalletPromoInfoStorage.shared.getDestinationToken(from: wallet.address.description) != nil
    self.advancedSettingsView.updateIsPromoWallet(isPromo)
    self.hamburgerMenu.update(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.walletObject
    )
    self.hamburgerMenu.hideMenu(animated: false)
    self.loadSwapSuggestionIfNeeded()
    self.view.layoutIfNeeded()
  }

  func coordinatorUpdateWalletObjects() {
    self.viewModel.updateWalletObject()
    self.walletNameLabel.text = self.viewModel.walletNameString
    self.hamburgerMenu.update(
      walletObjects: KNWalletStorage.shared.wallets,
      currentWallet: self.viewModel.walletObject
    )
    self.view.layoutIfNeeded()
  }

  func coordinatorUpdateTokenBalance(_ balances: [String: Balance]) {
    self.viewModel.updateBalance(balances)
    self.balanceLabel.text = self.viewModel.balanceText
    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.view.layoutIfNeeded()
  }

  /*
   Update estimate rate, check if the from, to, amount are all the same as current value in the model
   Update UIs according to new values
   */
  func coordinatorDidUpdateEstimateRate(from: TokenObject, to: TokenObject, amount: BigInt, rate: BigInt, slippageRate: BigInt) {
    let updated = self.viewModel.updateExchangeRate(
      for: from,
      to: to,
      amount: amount,
      rate: rate,
      slippageRate: slippageRate
    )
    self.updateExchangeRateField()
    if self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.text = self.viewModel.expectedReceivedAmountText
      self.viewModel.updateAmount(self.toAmountTextField.text ?? "", isSource: false)
    } else {
      self.fromAmountTextField.text = self.viewModel.expectedExchangeAmountText
      self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true)
    }
    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }

    self.updateAdvancedSettingsView()
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    if updated { self.loadingRateIndicator.isHidden = true }
    if self.viewModel.isTappedSwapAllBalance {
      self.keyboardSwapAllButtonPressed(self)
      self.viewModel.isTappedSwapAllBalance = false
    }
    self.view.layoutIfNeeded()
  }

  /*
   Update estimate gas limit, check if the from, to, amount are all the same as current value in the model    Update UIs according to new values
   */
  func coordinatorDidUpdateEstimateGasUsed(from: TokenObject, to: TokenObject, amount: BigInt) {
    let defaultValue = self.viewModel.getDefaultGasLimit(for: from, to: to)
    let estValue = self.viewModel.getEstValueGasLimit(for: from, to: to, amount: amount)
    var gasValue = BigInt()
    if (from.isGasFixed || to.isGasFixed) && (!self.viewModel.isAbleToUseReverseRouting || !self.viewModel.isUsingReverseRouting) {
      gasValue = max(defaultValue, estValue)
    } else {
      gasValue = min(defaultValue, estValue)
    }
    self.viewModel.updateEstimateGasLimit(
      for: from,
      to: to,
      amount: amount,
      gasLimit: gasValue
    )
    self.updateFromAmountUIForSwapAllBalanceIfNeeded()
    self.viewModel.lastSuccessLoadGasLimitTimeStamp = Date().timeIntervalSince1970
    if self.isViewSetup {
      self.advancedSettingsView.updateGasLimit(self.viewModel.estimateGasLimit)
    }
  }

  func coordinatorDidUpdateDefaultGasLimit(from: TokenObject, to: TokenObject, gasLimit: BigInt) {
    self.viewModel.updateDefaultGasLimit(
      for: from,
      to: to,
      gasLimit: gasLimit
    )
  }

  func coordinatorDidUpdateEstValueGasLimit(from: TokenObject, to: TokenObject, amount: BigInt, gasLimit: BigInt) {
    self.viewModel.updateEstValueGasLimit(
      for: from,
      to: to,
      amount: amount,
      gasLimit: gasLimit
    )
  }

  /*
   Update selected token
   - token: New selected token
   - isSource: true if selected token is from, otherwise it is to
   Update UIs according to new values
   */
  func coordinatorUpdateSelectedToken(_ token: TokenObject, isSource: Bool, isWarningShown: Bool = true) {
    if isSource, !self.fromTokenButton.isEnabled { return }
    if !isSource, !self.toTokenButton.isEnabled { return }
    if isSource, self.viewModel.from == token { return }
    if !isSource, self.viewModel.to == token { return }
    self.viewModel.updateSelectedToken(token, isSource: isSource)
    // support for promo wallet
    let isUpdatedTo: Bool = {
      if token.isPromoToken, isSource,
        let dest = KNWalletPromoInfoStorage.shared.getDestinationToken(from: self.viewModel.walletObject.address),
        let destToken = KNSupportedTokenStorage.shared.supportedTokens.first(where: { $0.symbol == dest.uppercased() }) {
        self.viewModel.updateSelectedToken(destToken, isSource: false)
        return true
      }
      return !isSource
    }()

    if self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.text = self.viewModel.amountFrom
      self.toAmountTextField.text = self.viewModel.expectedReceivedAmountText
    } else {
      self.toAmountTextField.text = self.viewModel.amountTo
      self.fromAmountTextField.text = self.viewModel.expectedExchangeAmountText
    }
    self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true)
    self.viewModel.updateAmount(self.toAmountTextField.text ?? "", isSource: false)
    self.updateTokensView(updatedFrom: isSource, updatedTo: isUpdatedTo)
    if self.viewModel.from == self.viewModel.to && isWarningShown {
      self.showWarningTopBannerMessage(
        with: NSLocalizedString("unsupported", value: "Unsupported", comment: ""),
        message: NSLocalizedString("can.not.swap.same.token", value: "Can not swap the same token", comment: ""),
        time: 1.5
      )
    }
    if isSource && !self.viewModel.isFocusingFromAmount {
      self.updateRateDestAmountDidChangeIfNeeded(prevDest: BigInt(0), isForceLoad: true)
    }
    self.updateEstimatedGasLimit()
    self.updateSwapHint(from: self.viewModel.from, to: self.viewModel.to, amount: self.viewModel.amountFromStringParameter)
    self.advancedSettingsView.updateIsUsingReverseRoutingStatus(value: true)
    self.viewModel.isUsingReverseRouting = true
    self.view.layoutIfNeeded()
  }

  /*
   Result from sending exchange token
   */
  func coordinatorExchangeTokenDidReturn(result: Result<String, AnyError>) {
    if case .failure(let error) = result {
      self.displayError(error: error)
    }
  }

  /*
  Rate validate for swapping
   */
  func coordinatorDidValidateRate() {
    self.validateDataBeforeContinuing(hasCallValidateRate: true)
  }

  /*
   Show transaction status after user confirmed transaction
   */
  func coordinatorExchangeTokenUserDidConfirmTransaction() {
    // Reset exchange amount
    self.viewModel.updateAmount("", isSource: true)
    self.viewModel.updateAmount("", isSource: false)
    self.viewModel.updateFocusingField(true)
    self.toAmountTextField.text = ""
    self.fromAmountTextField.text = ""
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.updateExchangeRateField()
    self.view.layoutIfNeeded()
  }

  func coordinatorTrackerRateDidUpdate() {
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.updateExchangeRateField()
  }
  
  func coordinatorUpdateGasWarningLimit() {
    self.updateGasWarningUI()
  }

  func coordinatorUpdateProdCachedRates() {
    self.viewModel.updateProdCachedRate()
    self.updateExchangeRateField()
  }

  func coordinatorUpdateComparedRateFromNode(from: TokenObject, to: TokenObject, rate: BigInt) {
    if self.viewModel.from == from, self.viewModel.to == to {
      self.viewModel.updateProdCachedRate(rate)
      self.updateExchangeRateField()
    }
  }

  /*
   - gasPrice: new gas price after user finished selected gas price from set gas price view
   */
  func coordinatorExchangeTokenDidUpdateGasPrice(_ gasPrice: BigInt?) {
    if let gasPrice = gasPrice {
      self.viewModel.updateGasPrice(gasPrice)
      self.updateFromAmountUIForSwapAllBalanceIfNeeded()
    }
    self.view.layoutIfNeeded()
  }

  func coordinatorDidUpdatePendingTransactions(_ transactions: [KNTransaction]) {
    self.hamburgerMenu.update(transactions: transactions)
    self.hasPendingTxView.isHidden = transactions.isEmpty
    self.view.layoutIfNeeded()
  }

  func coordinatorDidUpdateSwapHint(from: String, to: String, hint: String) {
    if from == self.viewModel.from.address && to == self.viewModel.to.address {
      let isHintChanged = hint != self.viewModel.swapHint.2
      self.viewModel.swapHint = (from, to, hint)
      if isHintChanged {
        // reload rate and gas limit when hint is changed
        self.updateEstimatedRate(showError: false, showLoading: true)
        self.updateEstimatedGasLimit()
      }
      if self.advancedSettingsView.updateIsAbleToUseReverseRouting(value: self.viewModel.isAbleToUseReverseRouting) && self.advancedSettingsView.isExpanded {
        self.advancedSettingsView.displayViewButtonPressed(self)
      }
    }
  }

  func coordinatorFailUpdateSwapHint(from: String, to: String) {
    if self.viewModel.swapHint.0 != from || self.viewModel.swapHint.1 != to {
      let isHintChanged = "" != self.viewModel.swapHint.2 && "0x" != self.viewModel.swapHint.2
      self.viewModel.swapHint = (from, to, "")
      if isHintChanged {
        // reload rate and gas limit when hint is changed
        self.updateEstimatedRate(showError: false, showLoading: true)
        self.updateEstimatedGasLimit()
      }
      if self.advancedSettingsView.updateIsAbleToUseReverseRouting(value: self.viewModel.isAbleToUseReverseRouting) && self.advancedSettingsView.isExpanded {
        self.advancedSettingsView.displayViewButtonPressed(self)
      }
    }
  }
}

// MARK: UITextFieldDelegate
extension KSwapViewController: UITextFieldDelegate {
  func textFieldShouldClear(_ textField: UITextField) -> Bool {
    textField.text = ""
    self.viewModel.updateFocusingField(textField == self.fromAmountTextField)
    self.viewModel.updateAmount("", isSource: textField == self.fromAmountTextField)
    self.viewModel.isSwapAllBalance = false
    self.updateViewAmountDidChange()
    self.updateEstimatedRate(showError: true, showLoading: true)
    self.updateEstimatedGasLimit()
    return false
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    let prevDest = self.toAmountTextField.text ?? ""
    let text = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string).cleanStringToNumber()
    if textField == self.fromAmountTextField && text.amountBigInt(decimals: self.viewModel.from.decimals) == nil { return false }
    if textField == self.toAmountTextField && text.amountBigInt(decimals: self.viewModel.to.decimals) == nil { return false }
    let double: Double = {
      if textField == self.fromAmountTextField {
        let bigInt = Double(text.amountBigInt(decimals: self.viewModel.from.decimals) ?? BigInt(0))
        return Double(bigInt) / pow(10.0, Double(self.viewModel.from.decimals))
      }
      let bigInt = Double(text.amountBigInt(decimals: self.viewModel.to.decimals) ?? BigInt(0))
      return Double(bigInt) / pow(10.0, Double(self.viewModel.to.decimals))
    }()
    if double > 1e9 && (textField.text?.count ?? 0) < text.count { return false } // more than 1B tokens
    textField.text = text
    self.viewModel.updateFocusingField(textField == self.fromAmountTextField)
    self.viewModel.updateAmount(text, isSource: textField == self.fromAmountTextField)
    self.updateViewAmountDidChange()
    if textField == self.toAmountTextField {
      let prevDestAmountBigInt = prevDest.removeGroupSeparator().amountBigInt(decimals: self.viewModel.to.decimals) ?? BigInt(0)
      self.updateRateDestAmountDidChangeIfNeeded(prevDest: prevDestAmountBigInt)
    }
    if self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = UIColor.Kyber.merigold
    } else {
      self.toAmountTextField.textColor = UIColor.Kyber.merigold
    }
    return false
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    self.viewModel.isSwapAllBalance = false
    let isFocusingSource = self.viewModel.isFocusingFromAmount
    self.viewModel.updateFocusingField(textField == self.fromAmountTextField)
    if self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = UIColor.Kyber.merigold
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else {
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
      self.toAmountTextField.textColor = UIColor.Kyber.merigold
    }
    if !self.viewModel.isFocusingFromAmount && isFocusingSource {
      self.updateRateDestAmountDidChangeIfNeeded(prevDest: BigInt(0), isForceLoad: true)
    }
    self.updateViewAmountDidChange()
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    if self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    } else {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.updateSwapHint(from: self.viewModel.from, to: self.viewModel.to, amount: self.viewModel.amountFromStringParameter)
    self.updateEstimatedRate(showError: true)
    self.updateEstimatedGasLimit()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      _ = self.showWarningDataInvalidIfNeeded()
    }
  }

  fileprivate func updateViewAmountDidChange(needUpdateEstRate: Bool = true) {
    if self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.text = self.viewModel.expectedReceivedAmountText
      self.viewModel.updateAmount(self.toAmountTextField.text ?? "", isSource: false)
    } else {
      self.fromAmountTextField.text = self.viewModel.expectedExchangeAmountText
      self.viewModel.updateAmount(self.fromAmountTextField.text ?? "", isSource: true)
    }
    if needUpdateEstRate { self.updateEstimatedRate(showLoading: true) }
    if !self.fromAmountTextField.isEditing && self.viewModel.isFocusingFromAmount {
      self.fromAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.toAmountTextField.textColor = UIColor.Kyber.mirage
    }
    if !self.toAmountTextField.isEditing && !self.viewModel.isFocusingFromAmount {
      self.toAmountTextField.textColor = self.viewModel.amountTextFieldColor
      self.fromAmountTextField.textColor = UIColor.Kyber.mirage
    }
    self.equivalentUSDValueLabel.text = self.viewModel.displayEquivalentUSDAmount
    self.updateExchangeRateField()
    self.view.layoutIfNeeded()
  }

  fileprivate func updateRateDestAmountDidChangeIfNeeded(prevDest: BigInt, isForceLoad: Bool = false) {
    let destAmount = self.viewModel.amountToBigInt
    let isChanged: Bool = {
      if isForceLoad { return true }
      if prevDest.isZero { return !destAmount.isZero }
      let percent = (Double(destAmount) - Double(prevDest)) / Double(prevDest) * 100.0
      return fabs(percent) >= 1.0
    }()
    if !isChanged { return } // no need to call if change is small
    KNRateCoordinator.shared.getCachedSourceAmount(
      from: self.viewModel.from,
      to: self.viewModel.to,
      destAmount: Double(destAmount) / pow(10.0, Double(self.viewModel.to.decimals))
    ) { [weak self] result in
      guard let `self` = self else { return }
      if case .success(let data) = result, let srcAmount = data, !srcAmount.isZero {
        let rate = destAmount * BigInt(10).power(self.viewModel.from.decimals) / srcAmount
        self.viewModel.updateAmount(
          srcAmount.fullString(decimals: self.viewModel.from.decimals).removeGroupSeparator(),
          isSource: true
        )
        self.viewModel.updateExchangeRate(
          for: self.viewModel.from,
          to: self.viewModel.to,
          amount: srcAmount,
          rate: rate,
          slippageRate: rate * BigInt(97) / BigInt(100)
        )
        self.updateTokensView(updatedFrom: false, updatedTo: false)
      }
      self.updateEstimatedRate(showError: true, showLoading: true)
    }
  }
}

// MARK: Advanced Settings View
extension KSwapViewController: KAdvancedSettingsViewDelegate {
  fileprivate func displayAdvancedSettingView() {
    UIView.animate(
      withDuration: 0.32,
      animations: {
        self.heightConstraintForAdvacedSettingsView.constant = self.advancedSettingsView.height
        self.updateAdvancedSettingsView()
        self.view.layoutIfNeeded()
    }, completion: { _ in
      if self.advancedSettingsView.isExpanded && self.scrollContainerView.contentSize.height > self.scrollContainerView.bounds.size.height {
        let offSetY: CGFloat = {
          if self.viewModel.isSwapSuggestionShown {
            let reverseRoutingSpace: CGFloat = self.viewModel.isAbleToUseReverseRouting ? 46.0 : 0.0
            return self.scrollContainerView.contentSize.height - self.scrollContainerView.bounds.size.height - 210.0 - reverseRoutingSpace
          }
          return self.scrollContainerView.contentSize.height - self.scrollContainerView.bounds.size.height
        }()
        guard offSetY > 0 else {
          return
        }
        let bottomOffset = CGPoint(
          x: 0,
          y: offSetY
        )
        self.scrollContainerView.setContentOffset(bottomOffset, animated: true)
      }
    }
    )
  }

  func kAdvancedSettingsView(_ view: KAdvancedSettingsView, run event: KAdvancedSettingsViewEvent) {
    switch event {
    case .displayButtonPressed:
      self.displayAdvancedSettingView()
    case .gasPriceChanged(let type, let value):
      self.viewModel.updateSelectedGasPriceType(type)
      self.viewModel.updateGasPrice(value)
      self.updateFromAmountUIForSwapAllBalanceIfNeeded()
      self.updateGasWarningUI()
      KNCrashlyticsUtil.logCustomEvent(withName: "advanced", customAttributes: ["gas_option": type.displayString(), "gas_value": self.viewModel.gasPriceText, "slippage": self.viewModel.slippageRateText ?? "0.0"])
    case .minRatePercentageChanged(let percent):
      self.viewModel.updateExchangeMinRatePercent(Double(percent))
      self.updateAdvancedSettingsView()
    case .infoPressed:
      let minRateDescVC: KMinAcceptableRatePopupViewController = {
        let viewModel = KMinAcceptableRatePopupViewModel(
          minRate: self.viewModel.slippageRateText ?? "0.0",
          symbol: self.viewModel.to.symbol
        )
        return KMinAcceptableRatePopupViewController(viewModel: viewModel)
      }()
      minRateDescVC.modalPresentationStyle = .overFullScreen
      minRateDescVC.modalTransitionStyle = .crossDissolve
      self.present(minRateDescVC, animated: true, completion: nil)
    case .helpPressed:
      KNCrashlyticsUtil.logCustomEvent(withName: "kbswap_gas_fee_info_tapped", customAttributes: nil)
      self.showBottomBannerView(
        message: "Gas.fee.is.the.fee.you.pay.to.the.miner".toBeLocalised(),
        icon: UIImage(named: "help_icon_large") ?? UIImage(),
        time: 10
      )
    case .changeIsUsingReverseRouting(let value):
      self.viewModel.isUsingReverseRouting = value
      self.updateEstimatedGasLimit()
      self.updateEstimatedRate(showError: true)
    case .reverseRoutingHelpPress:
      self.showBottomBannerView(
        message: "Reduce.gas.costs.by.routing.your.trade.to.predefined.reserves".toBeLocalised(),
        icon: UIImage(named: "help_icon_large") ?? UIImage(),
        time: 10
      )
    }
  }
}

// MARK: Hamburger Menu Delegate
extension KSwapViewController: KNBalanceTabHamburgerMenuViewControllerDelegate {
  func balanceTabHamburgerMenuViewController(_ controller: KNBalanceTabHamburgerMenuViewController, run event: KNBalanceTabHamburgerMenuViewEvent) {
    self.delegate?.kSwapViewController(self, run: event)
  }
}

// MARK: Toolbar delegate
extension KSwapViewController: KNCustomToolbarDelegate {
  func customToolbarLeftButtonPressed(_ toolbar: KNCustomToolbar) {
    self.keyboardSwapAllButtonPressed(toolbar)
  }

  func customToolbarRightButtonPressed(_ toolbar: KNCustomToolbar) {
    self.keyboardDoneButtonPressed(toolbar)
  }
}

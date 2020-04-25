// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Foundation

struct KNMarketCellViewModel {
  let pairName: String
  let price: String
  let volume: String
  let change24h: NSAttributedString
  let isFav: Bool
  let source: KNMarket

  init(market: KNMarket) {
    self.source = market
    var marketPairName = market.pair
    if marketPairName.contains("WETH") {
      marketPairName = marketPairName.replacingOccurrences(of: "WETH", with: "ETH*")
    } else if marketPairName.contains("ETH") {
      marketPairName = marketPairName.replacingOccurrences(of: "ETH", with: "ETH*")
    }
    let pairs = marketPairName.components(separatedBy: "_")
    self.pairName = "\(pairs.last ?? "")/\(pairs.first ?? "")"
    let formatter = NumberFormatterUtil.shared.doubleFormatter
    self.price = formatter.string(from: NSNumber(value: market.sellPrice)) ?? ""
    self.volume = formatter.string(from: NSNumber(value: market.volume)) ?? ""
    let upAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 12),
      NSAttributedStringKey.foregroundColor: UIColor(red: 49, green: 203, blue: 158),
    ]

    let downAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 12),
      NSAttributedStringKey.foregroundColor: UIColor(red: 250, green: 101, blue: 102),
    ]
    let zeroAttributes: [NSAttributedStringKey: Any] = [
      NSAttributedStringKey.font: UIFont.Kyber.medium(with: 12),
      NSAttributedStringKey.foregroundColor: UIColor.Kyber.grayChateau,
    ]
    var attributes: [NSAttributedStringKey: Any] = [:]
    if market.change == 0 {
      attributes = zeroAttributes
    } else if market.change > 0 {
      attributes = upAttributes
    } else {
      attributes = downAttributes
    }
    self.change24h = NSAttributedString(string: "\(fabs(market.change))%", attributes: attributes)
    self.isFav = KNAppTracker.isMarketFavourite(market.pair)
  }

  static func compareViewModel(left: KNMarketCellViewModel, right: KNMarketCellViewModel, type: MarketSortType) -> Bool {
    switch type {
    case .pair(let asc):
      return asc ? left.pairName < right.pairName : left.pairName > right.pairName
    case .price(let asc):
      return asc ? left.price < right.price : left.price > right.price
    case .volume(let asc):
      return asc ? left.volume < right.volume : left.volume > right.volume
    case .change(let asc):
      return asc ? left.change24h.string.dropLast() < right.change24h.string.dropLast() : left.change24h.string.dropLast() > right.change24h.string.dropLast()
    }
  }
}

protocol KNMarketTableViewCellDelegate: class {
  func marketTableViewCellDidSelectFavorite(_ cell: KNMarketTableViewCell, isFav: Bool)
}

class KNMarketTableViewCell: UITableViewCell {
  static let kCellID: String = "KNMarketTableViewCell"
  static let kCellHeight: CGFloat = 44

  @IBOutlet weak var pairNameLabel: UILabel!
  @IBOutlet weak var priceLabel: UILabel!
  @IBOutlet weak var volumeLabel: UILabel!
  @IBOutlet weak var changeButton: UIButton!
  @IBOutlet weak var favoriteButton: UIButton!

  var viewModel: KNMarketCellViewModel!
  weak var delegate: KNMarketTableViewCellDelegate?

  func updateViewModel(_ viewModel: KNMarketCellViewModel) {
    self.viewModel = viewModel
    self.pairNameLabel.text = viewModel.pairName
    self.priceLabel.text = viewModel.price.doubleValue == 0 ? "--" : viewModel.price
    self.volumeLabel.text = viewModel.volume.doubleValue == 0 ? "--" : viewModel.volume
    if viewModel.price.doubleValue == 0 {
      let zeroAttributes: [NSAttributedStringKey: Any] = [
        NSAttributedStringKey.font: UIFont.Kyber.medium(with: 12),
        NSAttributedStringKey.foregroundColor: UIColor.Kyber.grayChateau,
      ]
      self.changeButton.setAttributedTitle(NSAttributedString(string: "--", attributes: zeroAttributes), for: .normal)
    } else {
      self.changeButton.setAttributedTitle(viewModel.change24h, for: .normal)
    }
    let favImg = viewModel.isFav ? UIImage(named: "selected_fav_icon") : UIImage(named: "unselected_fav_icon")
    self.favoriteButton.setImage(favImg, for: .normal)
  }

  @IBAction func favouriteButtonTapped(_ sender: UIButton) {
    let updateFav = !self.viewModel.isFav
    self.delegate?.marketTableViewCellDidSelectFavorite(self, isFav: updateFav)
  }
}
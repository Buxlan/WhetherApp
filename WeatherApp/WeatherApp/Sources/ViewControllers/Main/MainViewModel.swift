//
//  MainViewModel.swift
//  WeatherApp
//
//  Created by  Buxlan on 9/22/21.
//

import Foundation
import CoreData
import UIKit

enum UserInterfaceStatus {
    case normal
    case loading
}

class MainViewModel: NSObject {
    
    typealias ItemType = City
    typealias ItemTypeData = CityData
    typealias CellDataType = MainDataModel
    typealias SectionDataType = MainDataModel
        
    weak var delegate: (NSFetchedResultsControllerDelegate
                        & Navigatable
                        & Updatable
                        & ViewModelStateDelegate
                        & ViewStateDelegate)? {
        didSet {
            resultsController.delegate = delegate
        }
    }
    
    private var locationManager: LocationManager = LocationManager()
    
    private var isLocationLoading: Bool = false {
        didSet {
            switch isLocationLoading {
            case true:
                delegate?.didChangeViewState(new: .loading)
            default:
                delegate?.didChangeTableViewState(new: .normal)
            }
        }
    }
    var isViewModelLoading: Bool = false {
        didSet {
            switch isViewModelLoading {
            case true:
                delegate?.didChangeTableViewState(new: .loading)
            default:
                delegate?.didChangeTableViewState(new: .normal)
            }
        }
    }
    
    private var managedObjectContext = CoreDataManager.shared.mainObjectContext
    private lazy var resultsController: MainFetchResultsController = {
        let resultsController = MainFetchResultsController(context: managedObjectContext)
        resultsController.delegate = delegate
        return resultsController
    }()
    // MARK: - Init
    
    // MARK: - Helper methods
    
    private var currentCityCompletionHandler: (() -> Void)?
    func performDeterminingCurrentCity() {
        if currentCityCompletionHandler != nil {
            // still searching current city
            return
        }
        let handler: () -> Void = { [weak self] in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                self.isLocationLoading = false
                self.currentCityCompletionHandler = nil
            }
        }
        isLocationLoading = true
        currentCityCompletionHandler = handler
        locationManager.performLocating(completionHandler: handler)
    }
    
    func reloadData() {
        guard delegate != nil else {
            return
        }
        managedObjectContext.perform {
            do {
                self.isViewModelLoading = true
                try self.resultsController.performFetch()
                self.delegate?.updateUserInterface()
                self.isViewModelLoading = false
            } catch {
                print(error)
            }
        }
    }
    
    func cellData(at indexPath: IndexPath) -> CellDataType {
        let item = self.item(at: indexPath)
        let text = item.name
        let detailText = "\(item.currentWeather?.temp ?? 0.0)"
        let cellModel = CellDataType(text: text, detailText: detailText)
        return cellModel
    }
    
    var numberOfSections: Int {
        resultsController.sections?.count ?? 0
    }
    
    func sectionData(section: Int) -> SectionDataType {
        guard let sections = resultsController.sections,
              sections.count > 0 else {
            return SectionDataType(text: "", detailText: nil)
        }
        if let sectionName = resultsController.sections?[section].name {
            switch sectionName {
            case "0":
                return SectionDataType(text: L10n.City.chosenCities,
                                       detailText: nil)
            case "1":
                return SectionDataType(text: L10n.City.yourCityTitle,
                                       detailText: nil)
            default:
                fatalError("Section with name \(sectionName) not found")
            }
        }
        fatalError("Section with index \(section) not found")
    }
//        if sections.count == 1 {
//            return SectionDataType(text: L10n.City.chosenCities,
//                                   detailText: nil)
//        } else {
//            switch section {
//            case 0:
//                return SectionDataType(text: L10n.City.yourCityTitle,
//                                       detailText: nil)
//            default:
//                return
//                    SectionDataType(text: L10n.City.chosenCities,
//                                           detailText: nil)
//            }
//        }
//    }
    
    func itemData(at indexPath: IndexPath) -> ItemTypeData {
        transform(from: resultsController.object(at: indexPath))
    }
    
    private func item(at indexPath: IndexPath) -> ItemType {
        resultsController.object(at: indexPath)
    }
    
    func numberOfRowsInSection(_ section: Int) -> Int {
        resultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func prepareSegue(to viewController: UIViewController, _ indexPath: IndexPath) {
        if let viewController = viewController as? DailyWeatherViewController {
            let city = item(at: indexPath)
            viewController.city = city
        }
    }
    
    private func transform(from item: ItemType?) -> ItemTypeData {
        guard let item = item else {
            return ItemTypeData()
        }
        return ItemTypeData(city: item)
    }
}

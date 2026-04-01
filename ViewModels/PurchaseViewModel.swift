//
//  PurchaseViewModel.swift
//  WiFiQualityMonitor
//

import Foundation
import StoreKit
import Combine

/// Manages the Remove Ads in-app purchase
@MainActor
final class PurchaseViewModel: ObservableObject {

    @Published var adsRemoved: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var showPurchaseSheet: Bool = false
    @Published var errorMessage: String?

    private let productID = "com.wqm.removeads"

    init() {
        adsRemoved = UserDefaultsManager.adsRemoved
        // Listen for transaction updates (restored purchases, etc.)
        Task { await listenForTransactions() }
    }

    // MARK: - Purchase

    func purchase() async {
        isPurchasing = true
        errorMessage = nil

        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                errorMessage = "Product not found"
                isPurchasing = false
                return
            }

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    adsRemoved = true
                    UserDefaultsManager.adsRemoved = true
                    showPurchaseSheet = false
                case .unverified:
                    errorMessage = "Purchase could not be verified"
                }
            case .pending:
                errorMessage = "Purchase is pending approval"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            // Check current entitlements
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   transaction.productID == productID {
                    adsRemoved = true
                    UserDefaultsManager.adsRemoved = true
                    return
                }
            }
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                adsRemoved = true
                UserDefaultsManager.adsRemoved = true
                await transaction.finish()
            }
        }
    }
}

import Foundation
import StoreKit

/// Manages StoreKit 2 subscriptions for Welcome Back Premium.
///
/// Product IDs must be registered in App Store Connect before live purchases work.
/// Use the bundled `Products.storekit` configuration file for Simulator testing.
@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    // MARK: - Published state

    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil

    // MARK: - Product identifiers

    static let monthlyProductID = "ai.juntunen.welcomeback.premium.monthly"
    static let yearlyProductID  = "ai.juntunen.welcomeback.premium.yearly"

    // MARK: - Free tier

    /// Maximum AI conversations per calendar month on the free plan.
    static let freeConversationLimit = 5

    /// Number of AI conversations started this calendar month.
    var monthlyConversationCount: Int {
        UserDefaults.standard.integer(forKey: monthlyCountKey)
    }

    /// Returns true when a free-tier user has hit the monthly conversation limit.
    var hasReachedFreeLimit: Bool {
        !isPremium && monthlyConversationCount >= Self.freeConversationLimit
    }

    func incrementConversationCount() {
        let current = UserDefaults.standard.integer(forKey: monthlyCountKey)
        UserDefaults.standard.set(current + 1, forKey: monthlyCountKey)
    }

    private var monthlyCountKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return "wb_conversations_\(c.year ?? 0)_\(c.month ?? 0)"
    }

    // MARK: - Lifecycle

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [
                Self.monthlyProductID,
                Self.yearlyProductID
            ])
            .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlement check

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            let isKnownProduct = tx.productID == Self.monthlyProductID
                              || tx.productID == Self.yearlyProductID
            if isKnownProduct && tx.revocationDate == nil {
                active = true
            }
        }
        isPremium = active
    }

    // MARK: - Private

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "Purchase verification failed. Please try again." }
    }
}

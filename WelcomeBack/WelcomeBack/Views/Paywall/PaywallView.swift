import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = SubscriptionService.shared
    @State private var selectedProductID: String = SubscriptionService.yearlyProductID
    @State private var isPurchasing = false

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 32)
                        .padding(.bottom, 32)

                    // Benefits
                    benefitsSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    // Product tiles
                    if store.products.isEmpty && !store.isLoading {
                        unavailableNote
                    } else {
                        productSection
                            .padding(.horizontal, 24)
                    }

                    // Purchase CTA
                    purchaseSection
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    // Restore + legal
                    footerSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                }
            }
        }
        .task { await store.loadProducts() }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.onSurface.opacity(0.3))
                    .padding(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .alert("Purchase Error", isPresented: .constant(store.purchaseError != nil)) {
            Button("OK") { store.purchaseError = nil }
        } message: {
            Text(store.purchaseError ?? "")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.accentYellow)

            Text("Welcome Back\nPremium")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)

            Text("Unlimited memories, unlimited conversations.")
                .font(.system(size: 16))
                .foregroundColor(.onSurface.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var benefitsSection: some View {
        VStack(spacing: 10) {
            benefitRow(icon: "infinity",             color: .accentYellow,  text: "Unlimited AI conversations each month")
            benefitRow(icon: "person.3.fill",        color: .green,         text: "Unlimited family members")
            benefitRow(icon: "bell.fill",            color: .red,           text: "Daily memory reminders")
            benefitRow(icon: "waveform.badge.mic",   color: .purple,        text: "Voice cloning (coming soon)")
            benefitRow(icon: "photo.on.rectangle",   color: .blue,          text: "Full photo library access")
        }
        .padding(20)
        .background(Color.surfaceVariant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.06)))
    }

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color == .accentYellow ? .black : .white))

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.onSurface)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.accentYellow)
        }
    }

    private var productSection: some View {
        VStack(spacing: 12) {
            if store.isLoading {
                ProgressView().tint(.accentYellow)
            } else {
                ForEach(store.products) { product in
                    productTile(product)
                }
            }
        }
    }

    private func productTile(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isYearly   = product.id == SubscriptionService.yearlyProductID
        return Button { selectedProductID = product.id } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(isSelected ? Color.accentYellow : Color.surfaceVariant)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .fill(Color.backgroundDark)
                            .frame(width: 10, height: 10)
                            .opacity(isSelected ? 1 : 0)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Annual" : "Monthly")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.onSurface)
                        if isYearly {
                            Text("Best value")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentYellow)
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.displayPrice + (isYearly ? " / year" : " / month"))
                        .font(.system(size: 13))
                        .foregroundColor(.onSurface.opacity(0.55))
                }

                Spacer()
            }
            .padding(16)
            .background(Color.surfaceVariant.opacity(isSelected ? 0.6 : 0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.accentYellow : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isYearly ? "Annual" : "Monthly") subscription: \(product.displayPrice)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var unavailableNote: some View {
        Text("Subscription products are not available in this environment.\nProducts must be configured in App Store Connect.")
            .font(.system(size: 13))
            .foregroundColor(.onSurface.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    private var purchaseSection: some View {
        Button(action: purchaseSelected) {
            HStack(spacing: 10) {
                if isPurchasing {
                    ProgressView().tint(.black)
                }
                Text(isPurchasing ? "Processing…" : "Subscribe Now")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.accentYellow)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || store.products.isEmpty)
        .accessibilityLabel("Subscribe to Welcome Back Premium")
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            Button(action: { Task { await store.restorePurchases(); if store.isPremium { dismiss() } } }) {
                Text("Restore Purchases")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.4))
                    .underline()
            }
            .buttonStyle(.plain)

            Text("Subscriptions auto-renew. Cancel any time in the App Store. Prices shown in your local currency.")
                .font(.system(size: 11))
                .foregroundColor(.onSurface.opacity(0.25))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func purchaseSelected() {
        guard let product = store.products.first(where: { $0.id == selectedProductID }) else { return }
        isPurchasing = true
        Task {
            await store.purchase(product)
            isPurchasing = false
            if store.isPremium { dismiss() }
        }
    }
}

#Preview {
    PaywallView()
        .preferredColorScheme(.dark)
}

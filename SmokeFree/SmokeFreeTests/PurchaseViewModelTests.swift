import Testing
import Foundation
@testable import SmokeFree

struct PurchaseViewModelTests {

    // MARK: - newTotalCost

    @Test func newTotalCost_multipliesQuantityAndPrice() {
        let vm = PurchaseViewModel()
        vm.newQuantity = 3
        vm.newPricePerPack = 25.0

        #expect(vm.newTotalCost == 75.0)
    }

    @Test func newTotalCost_isZero_whenQuantityZero() {
        let vm = PurchaseViewModel()
        vm.newQuantity = 0
        vm.newPricePerPack = 25.0

        #expect(vm.newTotalCost == 0)
    }

    // MARK: - newTotalCostText

    @Test func newTotalCostText_formatsWithOneDecimal() {
        let vm = PurchaseViewModel()
        vm.newQuantity = 2
        vm.newPricePerPack = 25.5

        #expect(vm.newTotalCostText == "¥51.0")
    }

    // MARK: - isFormValid

    @Test func isFormValid_true_whenBrandQuantityPriceValid() {
        let vm = PurchaseViewModel()
        vm.newBrand = "中华"
        vm.newQuantity = 1
        vm.newPricePerPack = 25.0

        #expect(vm.isFormValid)
    }

    @Test func isFormValid_false_whenBrandEmpty() {
        let vm = PurchaseViewModel()
        vm.newBrand = "   "
        vm.newQuantity = 1
        vm.newPricePerPack = 25.0

        #expect(!vm.isFormValid)
    }

    @Test func isFormValid_false_whenPriceZero() {
        let vm = PurchaseViewModel()
        vm.newBrand = "利群"
        vm.newQuantity = 1
        vm.newPricePerPack = 0

        #expect(!vm.isFormValid)
    }
}

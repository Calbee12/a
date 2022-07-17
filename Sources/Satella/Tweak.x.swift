import Cephei
import Orion
import SatellaC
import StoreKit

struct Core     : HookGroup {}
struct Receipt  : HookGroup {}
struct Observer : HookGroup {}
struct Sideload : HookGroup {}

class TransactionHook: ClassHook<SKPaymentTransaction> {
	typealias Group = Core
    
    // Make transaction state as purchased or restored (success values)

	func transactionState() -> SKPaymentTransactionState {
        return target.original != nil ? .restored : .purchased
    }
    
    func _setTransactionState(_ arg0: SKPaymentTransactionState) {
        arg0 == .restored ? orig._setTransactionState(.restored) : orig._setTransactionState(.purchased)
    }
    
    // Below just fixes crashes
	
	func _setError(_ arg0: NSError?) {
		orig._setError(nil)
	}
	
	func matchingIdentifier() -> String {
		"satella-mId-\(Int.random(in: 1...999999))"
	}
	
	func transactionIdentifier() -> String {
		"satella-tId-\(Int.random(in: 1...999999))"
	}
	
	func _transactionIdentifier() -> String {
		"satella-_tId-\(Int.random(in: 1...999999))"
	}
	
	func _setTransactionIdentifier(_ arg0: String) {
		orig._setTransactionIdentifier("satella-_tId-\(Int.random(in: 1...999999))")
	}
	
	func transactionDate() -> NSDate {
		NSDate()
	}
	
	func _setTransactionDate(_ arg0: NSDate) {
		orig._setTransactionDate(NSDate())
	}
}

// Disable sandbox maybe???

class PaymentHook: ClassHook<SKPayment> {
    typealias Group = Core
    
    func simulatesAskToBuyInSandbox() -> Bool {
        false
    }
}

// Allow purchase without a payment method

class QueueHook: ClassHook<SKPaymentQueue> {
	typealias Group = Core
	
	class func canMakePayments() -> Bool {
		true
	}
}

// Make the price mark as 0,00 to alleviate confusion

class ProductHook: ClassHook<SKProduct> {
    typealias Group = Core
    
    func price() -> NSDecimalNumber {
        0.01
    }
}

// Prevent receipt refreshes from breaking purchases

class RefreshHook: ClassHook<SKReceiptRefreshRequest> {
	typealias Group = Receipt
	
	func _wantsRevoked() -> Bool {
		false
	}
	
	func _wantsExpired() -> Bool {
		false
	}
}

// Refer to SatellaObserver.swift

class ObserverHook: ClassHook<SKPaymentQueue> {
	typealias Group = Observer
	
	func addTransactionObserver(_ arg0: SKPaymentTransactionObserver) {
		let tellaObserver = SatellaObserver.shared
		tellaObserver.observers.append(arg0)
		
		orig.addTransactionObserver(tellaObserver)
	}
}

// Refer to SatellaDelegate.swift

class RequestHook: ClassHook<SKProductsRequest> {
	typealias Group = Sideload
	
	func setDelegate(_ arg0: SKProductsRequestDelegate) {
		let tellaDelegate      = SatellaDelegate.shared
		tellaDelegate.delegate = arg0
		
		orig.setDelegate(tellaDelegate)
	}
}

// Redirect Apple's IAP verification to our server, which always returns "valid." Only works if the app does both:
// a) Uses /verifyReceipt on client device instead of on their server
// b) Doesn't also use local validation (can sometimes be mitigated using Receipts)

class VerifyHook: ClassHook<NSURL> {
	typealias Group = Receipt
	
	func initWithString(_ arg0: String) -> NSURL {
		return orig.initWithString(arg0.contains("apple.com/verifyReceipt") ? "https://drm.cypwn.xyz/verifyReceipt.php" : arg0)
	}
	
	class func URLWithString(_ arg0: String) -> NSURL {
		return orig.URLWithString(arg0.contains("apple.com/verifyReceipt") ? "http://drm.cypwn.xyz/verifyReceipt.php" : arg0)
	}
}

// Constructor

class Satella: Tweak {
	required init() {
		if Preferences.shared.shouldInit() {
			Core().activate()
			
			if Preferences.shared.receipts {
				Receipt().activate()
			}
			
			if Preferences.shared.observer {
				Observer().activate()
			}
			
			if Preferences.shared.sideloaded {
				Sideload().activate()
			}
		}
	}
}
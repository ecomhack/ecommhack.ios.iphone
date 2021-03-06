import UIKit
import FacesUI


class ProductsViewController: FacesViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIActionSheetDelegate, PayPalPaymentDelegate {
    @IBOutlet weak var userHelloLabel: HighlightedLabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var userImageView: UIImageView!
    
    @IBOutlet weak var topDescLabel: NormalLabel!
    @IBOutlet weak var descLabel: NormalLabel!
    @IBOutlet weak var nameLabel: NormalLabel!
    dynamic var product:Product?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Recommendation"
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.downloadProductContinously()
        
        self.userHelloLabel.text = "Hi \(self.api.user.name)!"
        if let image = self.api.user.avatar {
            self.userImageView.sd_setImageWithURL(image)
        }
        
        RACObserve(self, "product").subscribeNextAs { [weak self](product:Product) -> () in
            if let product = self?.product {
                self?.descLabel.text = product.brand
                self?.nameLabel.text = product.name
                self?.topDescLabel.text = "\(product.price) €"
                self?.collectionView.reloadData()
            }
        }
    }
    
    func downloadProductContinously() {
        
        self.api.getProduct({ (product) -> () in
            self.product = product
            }, failure: { () -> () in
                
        })
        let delayTime = dispatch_time(DISPATCH_TIME_NOW,
            Int64(3 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) { () -> Void in
            self.downloadProductContinously()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.setHidesBackButton(true, animated: true)
        
        PayPalMobile.preconnectWithEnvironment(PayPalEnvironmentNoNetwork)
        
    }
    
    @IBAction func logOutTapped(sender: AnyObject) {
        self.api.logOut()
        self.navigationController?.popToRootViewControllerAnimated(true)
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("imageCell", forIndexPath: indexPath) as! UICollectionViewCell
        
        if let cell = cell as? ProductImageCell {
            if let product = self.product {
                cell.configure(product.images[indexPath.row])
            }
        }
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let product = self.product {
            return product.images.count
        }
        return 0
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return self.collectionView.frame.size
    }
    
    
    // MARK: ActionSheet
    
    @IBAction func buyNowTapped(sender: UIButton) {
        self.actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil)
        self.actionSheet.addButtonWithTitle("Confirm payment")
        
        self.actionSheet.showFromRect(sender.frame, inView: self.view, animated: true)
    }
    var actionSheet:UIActionSheet!
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 1 {
            self.payWithPayPal(self.product!.price, name: self.product!.name)
        }
    }
    
    // MARK: PayPal
    
    lazy var paypalConfiguration:PayPalConfiguration = {
        let conf = PayPalConfiguration()
        conf.payPalShippingAddressOption = PayPalShippingAddressOption.PayPal
        conf.acceptCreditCards = false
        return conf
    }()
    
    var productToBuy:Product?
    func payWithPayPal(amount:NSDecimalNumber, name:String) {
        let payment = PayPalPayment()
        payment.amount = amount
        payment.currencyCode = "EUR"
        payment.shortDescription = name
        payment.intent = PayPalPaymentIntent.Order
        if (!payment.processable) {
            // If, for example, the amount was negative or the shortDescription was empty, then
            // this payment would not be processable. You would want to handle that here.
        }
        
        self.productToBuy = self.product
        let paymentViewController = PayPalPaymentViewController(payment: payment, configuration: self.paypalConfiguration, delegate: self)
        self.presentViewController(paymentViewController, animated: true, completion: nil)
    }
    
    func payPalPaymentDidCancel(paymentViewController: PayPalPaymentViewController!) {
        
        paymentViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func payPalPaymentViewController(paymentViewController: PayPalPaymentViewController!, didCompletePayment completedPayment: PayPalPayment!) {
        DLOG("\(completedPayment)")
        paymentViewController.dismissViewControllerAnimated(true, completion: nil)
        
        SVProgressHUD.showWithMaskType(.Black)
        self.api.buyProduct(self.productToBuy!, success: { () -> () in
            SVProgressHUD.dismiss()
        }) { () -> () in
            SVProgressHUD.dismiss()
        }
    }
    
}
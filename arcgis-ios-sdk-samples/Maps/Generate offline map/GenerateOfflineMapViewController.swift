//
// Copyright 2017 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit
import ArcGIS

class GenerateOfflineMapViewController: UIViewController {

    @IBOutlet var mapView:AGSMapView!
    @IBOutlet var extentView:UIView!
    @IBOutlet var barButtonItem:UIBarButtonItem!
    @IBOutlet var progressView:UIProgressView!
    @IBOutlet var progressLabel:UILabel!
    @IBOutlet var progressParentView:UIView!
    @IBOutlet var cancelButton:UIButton!
    
    private var portalItem:AGSPortalItem!
    private var parameters:AGSGenerateOfflineMapParameters!
    private var offlineMapTask:AGSOfflineMapTask!
    private var generateOfflineMapJob:AGSGenerateOfflineMapJob!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //add the source code button item to the right of navigation bar
        (self.navigationItem.rightBarButtonItem as! SourceCodeBarButtonItem).filenames = ["GenerateOfflineMapViewController"]

        //Auth Manager settings
        let config = AGSOAuthConfiguration(portalURL: nil, clientID: "xHx4Nj7q1g19Wh6P", redirectURL: "iOSSamples://auth")
        AGSAuthenticationManager.shared().oAuthConfigurations.add(config)
        AGSAuthenticationManager.shared().credentialCache.removeAllCredentials()
        
        let portal = AGSPortal.arcGISOnline(withLoginRequired: true)
        self.portalItem = AGSPortalItem(portal: portal, itemID: "acc027394bc84c2fb04d1ed317aac674")
        let map = AGSMap(item: self.portalItem)
        
        self.mapView.map = map
        
        self.mapView.map?.load(completion: { [weak self] (error) in
            
            if error == nil {
                self?.barButtonItem.isEnabled = true
            }
            })
        
        self.offlineMapTask = AGSOfflineMapTask(portalItem: self.portalItem)
        
        //setup extent view
        self.extentView.layer.borderColor = UIColor.red.cgColor
        self.extentView.layer.borderWidth = 3
    }
    
    private func defaultParameters() {
        
        self.offlineMapTask.defaultGenerateOfflineMapParameters(withAreaOfInterest: self.frameToExtent()) { (parameters: AGSGenerateOfflineMapParameters?, error: Error?) in
            
            if let error = error {
                SVProgressHUD.showError(withStatus: error.localizedDescription, maskType: .gradient)
            }
            else {
                
                self.parameters = parameters!
                self.takeMapOffline()
            }
        }
    }
    
    private func takeMapOffline() {
        
        //create a unique name for the geodatabase based on current timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fullPath = "\(path)/\(dateFormatter.string(from: Date())).geodatabase"
        
        self.generateOfflineMapJob = self.offlineMapTask.generateOfflineMapJob(with: self.parameters, downloadDirectory: URL(string: fullPath)!)
        
        //add observer for progress
        self.generateOfflineMapJob.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
        
        self.progressParentView.isHidden = false
        
        self.generateOfflineMapJob.start(statusHandler: { (status: AGSJobStatus) in
            
        }) { [weak self] (result:AGSGenerateOfflineMapResult?, error:Error?) in
            
            guard let weakSelf = self else {
                return
            }
            
            guard error == nil else {
                SVProgressHUD.showError(withStatus: error!.localizedDescription, maskType: .gradient)
                return
            }
            
            SVProgressHUD.dismiss()
            
            //disable cancel button
            weakSelf.cancelButton.isEnabled = false
            
            weakSelf.mapView.map = result?.offlineMap
            
            //remove KVO observer
            weakSelf.generateOfflineMapJob.progress.removeObserver(weakSelf, forKeyPath: "fractionCompleted", context: nil)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        DispatchQueue.main.async { [weak self] in
            
            guard let weakSelf = self else {
                return
            }
            
            if keyPath == "fractionCompleted" {
                let progress = weakSelf.generateOfflineMapJob.progress
                
                self?.progressLabel.text = progress.localizedDescription
                self?.progressView.progress = Float(progress.fractionCompleted)
            }
        }
    }
    
    @IBAction func action() {
        self.defaultParameters()
        
        //disable bar button item
        self.barButtonItem.isEnabled = false
        
        //hide the extent view
        self.extentView.isHidden = true
    }
    
    @IBAction func cancelAction() {
        
        //cancel generate offline map job
        self.generateOfflineMapJob.progress.cancel()
        
        self.progressParentView.isHidden = true
        self.progressView.progress = 0
        self.progressLabel.text = ""
        
        //enable take map offline bar button item
        self.barButtonItem.isEnabled = true
        
        //unhide the extent view
        self.extentView.isHidden = false
    }
    
    func frameToExtent() -> AGSEnvelope {
        let frame = self.mapView.convert(self.extentView.frame, from: self.view)
        
        let minPoint = self.mapView.screen(toLocation: frame.origin)
        let maxPoint = self.mapView.screen(toLocation: CGPoint(x: frame.origin.x+frame.width, y: frame.origin.y+frame.height))
        let extent = AGSEnvelope(min: minPoint, max: maxPoint)
        return extent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

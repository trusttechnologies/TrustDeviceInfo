  

# Trust Technologies

![image](https://avatars2.githubusercontent.com/u/42399326?s=200&v=4)

# Description

Trust is a platform that allows building trust and security between people and technology.

**Trust-device-info**  allows you to obtain a unique universal ID for each device from a set of characteristics of this device. It also allows the monitoring of device status changes, to have knowledge of the device status at all times.  

# Implementation
Add in your podfile:

``` Swift
platform :ios, '12.0'
source 'https://github.com/trusttechnologies/TrustDeviceInfoPodSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'

use_frameworks!
  

target 'NameApp' do

...

pod 'TrustDeviceInfo'

...

end
```

And execute:

```

pod install

```
# Initialize
To generate a new trustID

AccessGroup: To generate a new accessGroup we need activate our keychain sharing capability in our app, we must also belong to an Apple development group to access its identifier.

Team ID: Found it in [https://developer.apple.com/](https://developer.apple.com/)
![image](https://github.com/trusttechnologies/lat_trust_mobile_ios_trust-identify_library/blob/master/Apple%20Team%20id.png?raw=true)

"accessGroup" struct: "teamID.keychainName.id". 

Access group example: "A2D9N3HN.trustID.example"

clientID and clientSecret are generated in backend, request access codes to the provider.

 ```swift
import TrustDeviceInfo

extension AppDelegate: TrustDeviceInfoDelegate {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		let serviceName = "defaultServiceName"
		let accessGroup = "A2D9N3HN.trustID.example"
		let clientID = "example890348h02758a5f8bee4ba2d7880a48d0581e9efb"
		let clientSecret = "example8015437e7a963dacaa778961f647aa37f6730bd"

		Identify.shared.trustDeviceInfoDelegate = self
		Identify.shared.set(serviceName: serviceName, accessGroup: accessGroup)
		Identify.shared.createClientCredentials(clientID: clientID, clientSecret: clientSecret)
		Identify.shared.enable()

		return  true
	}
	
	func onClientCredentialsSaved(savedClientCredentials: ClientCredentials) {
		//You can do something
	}

	func onTrustIDSaved(savedTrustID: String) {
		//You can do something
	}

	func onRegisterFirebaseTokenSuccess(responseData: RegisterFirebaseTokenResponse) {
		//You can do something
	}

	func onSendDeviceInfoResponse(status: ResponseStatus) {
		//You can do something
	}
}
```

# Permissions

As mentioned above, we must activate the keychain sharing capability and set our new "Keychain Group" 

![Image](https://github.com/trusttechnologies/lat_trust_mobile_ios_trust-identify_library/blob/master/keychain%20capability.png?raw=true)

*NOTE: Remember your keychain groups to share information between apps with the same team ID.*

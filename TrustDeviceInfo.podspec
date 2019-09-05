Pod::Spec.new do |s|

  s.platform     = :ios
  s.ios.deployment_target = '12.1'
  s.name         = "TrustDeviceInfo"
  s.summary      = "Small library that allows the user to gather information about the device in use. Developed by Jumpitt Labs."
  s.requires_arc = true

  s.version      = "1.0.3"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "Kevin Torres" => "ktorres@jumpitt.com" }
  
  s.homepage     = "https://github.com/trusttechnologies/TrustDeviceInfo"

  s.source       = { :git => "https://github.com/trusttechnologies/TrustDeviceInfo.git", :tag => "#{s.version}" }

  s.framework = "UIKit"

  s.dependency 'Alamofire', '~> 4.8.2'
  s.dependency 'AlamofireObjectMapper'
  s.dependency 'DeviceKit'

  s.source_files  = "TrustDeviceInfo/**/*.{swift}"
  s.swift_version = "4.2"

end
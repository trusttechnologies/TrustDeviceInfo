Pod::Spec.new do |s|

  s.platform     = :ios
  s.ios.deployment_target = '11.4'
  s.name         = "TrustDeviceInfo"
  s.summary      = "Small library that allows the user to obtain information about the device in use. Developed by Jumpitt Labs."
  s.requires_arc = true

  s.version      = "0.1.4"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "Diego Villouta Fredes" => "diegov17@gmail.com" }

  s.homepage     = "https://github.com/trusttechnologies/TrustDeviceInfo"

  s.source       = { :git => "https://github.com/trusttechnologies/TrustDeviceInfo.git", :tag => "#{s.version}" }

  s.framework = "UIKit"

  s.dependency 'Alamofire', '~> 4.7'
  s.dependency 'DeviceKit'

  s.source_files  = "TrustDeviceInfo/**/*.{swift}"
  s.swift_version = "4.2"

end

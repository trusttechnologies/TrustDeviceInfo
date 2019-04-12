Pod::Spec.new do |s|

  s.platform     = :ios
  s.ios.deployment_target = '12.1'
  s.name         = "TrustDeviceInfo"
  s.summary      = "Small library that allows the user to gather information about the device in use. Developed by Jumpitt Labs."
  s.requires_arc = true

  s.version      = "0.3.0"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "Diego Villouta Fredes" => "diegov17@gmail.com" }

  s.homepage     = "https://github.com/trusttechnologies/TrustDeviceInfo"

  s.source       = { :git => "https://github.com/trusttechnologies/TrustDeviceInfo.git", :tag => "#{s.version}" }

  s.framework = "UIKit"

  s.dependency 'Alamofire'
  s.dependency 'DeviceKit', '~> 1.13'

  s.source_files  = "TrustDeviceInfo/**/*.{swift}"
  s.swift_version = "4.2"

end

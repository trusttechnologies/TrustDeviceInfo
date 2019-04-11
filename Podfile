# Uncomment the next line to define a global platform for your project
platform :ios, '12.1'

use_frameworks!

target 'TrustDeviceInfo' do
    pod 'Alamofire'
    pod 'DeviceKit', '~> 1.13'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = ‘4.2’
        end
    end
    
    installer.pods_project.build_configurations.each do |config|
        config.build_settings.delete('CODE_SIGNING_ALLOWED')
        config.build_settings.delete('CODE_SIGNING_REQUIRED')
    end
end

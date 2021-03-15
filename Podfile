# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'AdBlock' do
    platform :osx, '10.12'
    # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!

    #pod 'Firebase/Core'

    pod 'Alamofire', '~> 4.7'
    pod 'SwiftyBeaver'
    pod 'Punycode-Cocoa'
    pod 'SwiftyStoreKit', '~> 0.13.0'
    pod 'GRKOpenSSLFramework'
    pod 'SwiftSoup'
end

target 'AdBlock-Extension' do
    platform :osx, '10.12'
    # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!

    pod 'Alamofire', '~> 4.7'
    pod 'SwiftyBeaver'
    pod 'Punycode-Cocoa'
    pod 'SwiftSoup'
end

target 'AdBlock-Safari-Menu' do
    platform :osx, '10.12'
    # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!

    pod 'Alamofire', '~> 4.7'
    pod 'SwiftyBeaver'
    pod 'Punycode-Cocoa'
    pod 'SwiftyStoreKit', '~> 0.13.0'
    pod 'SwiftSoup'
end

target 'AdBlock-Tests' do
    platform :osx, '10.12'
    # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!

    pod 'Alamofire', '~> 4.7'
    pod 'SwiftyBeaver'
    pod 'Punycode-Cocoa'
    pod 'SwiftSoup'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
        end
    end
end

source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '8.0'

use_frameworks!
workspace 'LDSContent'

target 'LDSContent' do
    project 'LDSContent.xcodeproj'

    pod 'Operations'
    pod 'SQLite.swift', '0.10.1'
    pod 'FTS3HTMLTokenizer', '~> 2.0', :inhibit_warnings => true
    pod 'Swiftification', '6.0.1'
    pod 'SSZipArchive'
    
    target 'LDSContentTests' do
    end
    
    target 'LDSContentDemo' do
        project 'LDSContentDemo.xcodeproj'
    
        pod 'SVProgressHUD'
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '2.3'
        end
    end
end

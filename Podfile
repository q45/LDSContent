source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'

use_frameworks!
workspace 'LDSContent'

target 'LDSContent' do
    project 'LDSContent.xcodeproj'

    pod 'ProcedureKit', '4.0.0.beta.4'
    pod 'SQLite.swift'
    pod 'FTS3HTMLTokenizer', '~> 2.0', :inhibit_warnings => true
    pod 'Swiftification'
    pod 'SSZipArchive'
    
    target 'LDSContentTests' do
    end
    
    target 'LDSContentDemo' do
        project 'LDSContentDemo.xcodeproj'
    
        pod 'SVProgressHUD'
    end
end

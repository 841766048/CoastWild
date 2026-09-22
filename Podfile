source 'https://cdn.cocoapods.org/'
platform :ios, '17.0'
use_frameworks! :linkage => :static

project 'CoastWild.xcodeproj'
target 'CoastWild' do
  pod 'IQKeyboardManagerSwift', '~> 8.0'
  pod 'BRPickerView/DatePicker', '~> 3.0'
  pod 'Adjust', '5.8.0'
  target 'CoastWildUITests' do
    # UI tests run out of process and import only XCTest, not the app's SDKs.
    inherit! :none
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless target.name.start_with?('BRPickerView')
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end

platform :ios, '15.0'
use_frameworks!

target 'itchio' do
  pod 'GCDWebServer'
end

# 新版 Xcode 移除了 libarclite（旧部署目标的 ARC 兼容库），
# 强制所有 pod 部署目标 >= 15.0，避免链接失败。
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end

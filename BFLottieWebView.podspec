Pod::Spec.new do |s|
  s.name             = 'BFLottieWebView'
  s.version          = '0.1.1'
  s.summary          = 'A WKWebView + lottie-web renderer packaged as a reusable UIView.'

  s.description      = <<-DESC
  BFLottieWebView renders a Lottie JSON using lottie-web inside WKWebView.

  Features:
  - Local-only lottie-web (no CDN)
  - View API: load / play / pause / stop / setProgress / setSpeed
  - Event callbacks: ready / loaded / firstFrame / error
  - Reduced white flash by keeping the web view hidden until first frame
  - Optional prewarm to reduce cold-start time
  DESC

  s.homepage         = 'https://github.com/mirbf/BFLottieWebView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Bfchen' => '2946779829@qq.com' }
  s.source           = { :git => 'https://github.com/mirbf/BFLottieWebView.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.requires_arc = true

  s.source_files = 'BFLottieWebView/Classes/**/*.{h,m}'
  s.public_header_files = 'BFLottieWebView/Classes/**/*.h'

  s.resource_bundles = {
    'BFLottieWebView' => ['BFLottieWebView/Assets/**/*']
  }

  s.frameworks = 'UIKit', 'Foundation', 'WebKit'

  # Xcode may treat this warning as error in some projects.
  s.pod_target_xcconfig = {
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER' => 'NO'
  }
end

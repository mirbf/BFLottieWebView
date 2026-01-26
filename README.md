# BFLottieWebView

A small UIView that renders Lottie JSON via WKWebView + lottie-web (local, no CDN).

## Features

- Local-only `lottie.min.js` from the pod resource bundle
- Simple UIView API: load / play / pause / stop / setProgress / setSpeed
- Event callback: ready / loaded / firstFrame / error
- Reduce white flash: hide WKWebView until first frame
- Optional prewarm to reduce cold-start time

## Requirements

- iOS 13.0+
- UIKit + WebKit

## Installation

### CocoaPods

After the pod is published to CocoaPods Trunk:

```ruby
pod 'BFLottieWebView'
```

Use GitHub directly (without Trunk):

```ruby
pod 'BFLottieWebView', :git => 'https://github.com/mirbf/BFLottieWebView.git', :tag => '0.1.0'
```

Local development:

```ruby
pod 'BFLottieWebView', :path => '../BFLottieWebView'
```

## Usage

Objective-C:

```objective-c
#import <BFLottieWebView/BFLottieWebView.h>

BFLottieWebView *view = [[BFLottieWebView alloc] initWithFrame:CGRectZero];
view.renderer = BFLottieWebRendererSVG;
view.loop = YES;
view.speed = 1.0;

[view loadAnimationWithJSONData:jsonData completion:^(BOOL success, NSError * _Nullable error) {
  if (!success) {
    NSLog(@"Load failed: %@", error);
  }
}];

[view play];
```

## Notes

- This pod loads the tool HTML via `loadFileURL:allowingReadAccessToURL:`.
- Errors are reported via `eventHandler` with extra fields (e.g. `stage/domain/code/url`) when available.

## License

MIT.

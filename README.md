# TSClusterMapView - MKMapView with clustering

Animated annotation clustering MKMapView subclass based off of [ADClusterMapView][].

[ADClusterMapView]: https://github.com/applidium/ADClusterMapView

[![CI Status](http://img.shields.io/travis/ashare80/TSClusterMapView.svg?style=flat)](https://travis-ci.org/ashare80/TSClusterMapView)
[![Version](https://img.shields.io/cocoapods/v/TSClusterMapView.svg?style=flat)](http://cocoadocs.org/docsets/TSClusterMapView)
[![License](https://img.shields.io/cocoapods/l/TSClusterMapView.svg?style=flat)](http://cocoadocs.org/docsets/TSClusterMapView)
[![Platform](https://img.shields.io/cocoapods/p/TSClusterMapView.svg?style=flat)](http://cocoadocs.org/docsets/TSClusterMapView)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

TSClusterMapView is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "TSClusterMapView"

## Quick start

Subclass TSClusterMapView with your new or existing MKMapView

```objective-c
#import "TSClusterMapView.h"

@interface YourMapView : TSClusterMapView <MKMapViewDelegate, TSClusterMapViewDelegate>
```

Add annotations to be clustered using the add clustered annotation methods and single annotations using the standard add annotation.

```objective-c
- (void)addClusteredAnnotation:(id<MKAnnotation>)annotation;

- (void)addClusteredAnnotations:(NSArray *)annotations;
```



## Author

Adam Share, adam@tapshield.com

## License

TSClusterMapView is available under the MIT license. See the LICENSE file for more info.


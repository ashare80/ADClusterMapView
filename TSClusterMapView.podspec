#
# Be sure to run `pod lib lint TSClusterMapView.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "TSClusterMapView"
  s.version          = "2.3.2"
  s.summary          = "Animated annotation clustering MKMapView subclass"
  s.description      = <<-DESC
                       This animated annotation clustering MKMapView subclass is based off of ADClusterMapView.

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://github.com/ashare80/TSClusterMapView"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Adam Share" => "adam@tapshield.com" }
  s.source           = { :git => "https://github.com/ashare80/TSClusterMapView.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.9'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.ios.frameworks = 'UIKit', 'MapKit'
  s.osx.frameworks = 'MapKit'
end

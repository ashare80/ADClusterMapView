//
//  CDMapViewController.h
//  ClusterDemo
//
//  Created by Patrick Nollet on 09/10/12.
//  Copyright (c) 2012 Applidium. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TSClusterMapView.h"

static NSString * const CDStreetLightJsonFile = @"CDStreetlights";
static NSString * const kStreetLightAnnotationImage = @"StreetLightAnnotationYellow";

static NSString * const CDToiletJsonFile = @"CDToilets";
static NSString * const kBathroomAnnotationImage = @"BathroomAnnotationGreen";

@interface CDMapViewController : UIViewController <TSClusterMapViewDelegate, UITabBarDelegate>

@property (strong, nonatomic) IBOutlet TSClusterMapView * mapView;

@property (weak, nonatomic) IBOutlet UITabBar *tabBar;
@property (weak, nonatomic) IBOutlet UITabBarItem *bathroomTabBarItem;
@property (weak, nonatomic) IBOutlet UITabBarItem *streetLightsTabBarItem;
@property (weak, nonatomic) IBOutlet UIStepper *stepper;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

- (IBAction)addAll:(id)sender;
- (IBAction)removeAll:(id)sender;
- (IBAction)stepperValueChanged:(id)sender;
- (IBAction)segmentedControlValueChanged:(id)sender;
- (IBAction)sliderValueChanged:(id)sender;

@property (strong, nonatomic) NSMutableArray *streetLightAnnotations;
@property (strong, nonatomic) NSMutableArray *bathroomAnnotations;

@property (strong, nonatomic) NSMutableArray *streetLightAnnotationsAdded;
@property (strong, nonatomic) NSMutableArray *bathroomAnnotationsAdded;

@end

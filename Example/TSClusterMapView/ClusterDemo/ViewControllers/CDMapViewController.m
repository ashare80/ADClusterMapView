//
//  CDMapViewController.m
//  ClusterDemo
//
//  Created by Patrick Nollet on 09/10/12.
//  Copyright (c) 2012 Applidium. All rights reserved.
//

#import "CDMapViewController.h"
#import "ADBaseAnnotation.h"
#import "TSBathroomAnnotation.h"
#import "TSStreetLightAnnotation.h"
#import "TSDemoClusteredAnnotationView.h"



@interface CDMapViewController ()

@property (strong, nonatomic) NSDate *startTime;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@end


@implementation CDMapViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];

    [_mapView setRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(48.857617, 2.338820), MKCoordinateSpanMake(1.0, 1.0))];
    _mapView.clusterDiscrimination = 1.0;
    
    [_tabBar setSelectedItem:_bathroomTabBarItem];
    
    [self parseJsonData];
    
    [self refreshBadges];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(kdTreeLoadingProgress:)
                                                 name:KDTreeClusteringProgress
                                               object:nil];
}


#pragma mark - MKMapViewDelegate
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    
    MKAnnotationView *view;
    
    if ([annotation isKindOfClass:[TSStreetLightAnnotation class]]) {
        view = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:NSStringFromClass([TSStreetLightAnnotation class])];
        if (!view) {
            view = [[MKAnnotationView alloc] initWithAnnotation:annotation
                                                   reuseIdentifier:NSStringFromClass([TSStreetLightAnnotation class])];
            view.image = [UIImage imageNamed:kStreetLightAnnotationImage];
            view.canShowCallout = YES;
            view.centerOffset = CGPointMake(view.centerOffset.x, -view.frame.size.height/2);
        }
    }
    else if ([annotation isKindOfClass:[TSBathroomAnnotation class]]) {
        view = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:NSStringFromClass([TSBathroomAnnotation class])];
        if (!view) {
            view = [[MKAnnotationView alloc] initWithAnnotation:annotation
                                                reuseIdentifier:NSStringFromClass([TSBathroomAnnotation class])];
            view.image = [UIImage imageNamed:kBathroomAnnotationImage];
            view.canShowCallout = YES;
            view.centerOffset = CGPointMake(view.centerOffset.x, -view.frame.size.height/2);
        }
    }
    
    return view;
}


#pragma mark - ADClusterMapView Delegate

- (MKAnnotationView *)mapView:(TSClusterMapView *)mapView viewForClusterAnnotation:(id<MKAnnotation>)annotation {
    
    TSDemoClusteredAnnotationView * view = (TSDemoClusteredAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:NSStringFromClass([TSDemoClusteredAnnotationView class])];
    if (!view) {
        view = [[TSDemoClusteredAnnotationView alloc] initWithAnnotation:annotation
                                                            reuseIdentifier:NSStringFromClass([TSDemoClusteredAnnotationView class])];
    }
    
    return view;
}

- (void)mapView:(TSClusterMapView *)mapView willBeginBuildingClusterTreeForMapPoints:(NSSet<ADMapPointAnnotation *> *)annotations {
    NSLog(@"Kd-tree will begin mapping item count %lu", (unsigned long)annotations.count);
    
    _startTime = [NSDate date];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (annotations.count > 10000) {
            [_progressView setHidden:NO];
        }
        else {
            [_progressView setHidden:YES];
        }
    }];
}

- (void)mapView:(TSClusterMapView *)mapView didFinishBuildingClusterTreeForMapPoints:(NSSet<ADMapPointAnnotation *> *)annotations {
    NSLog(@"Kd-tree finished mapping item count %lu", (unsigned long)annotations.count);
    NSLog(@"Took %f seconds", -[_startTime timeIntervalSinceNow]);
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_progressView setHidden:YES];
        _progressView.progress = 0.0;
    }];
}

- (void)mapViewWillBeginClusteringAnimation:(TSClusterMapView *)mapView{
    
     NSLog(@"Animation operation will begin");
}

- (void)mapViewDidCancelClusteringAnimation:(TSClusterMapView *)mapView {
    
    NSLog(@"Animation operation cancelled");
}

- (void)mapViewDidFinishClusteringAnimation:(TSClusterMapView *)mapView{
    
    NSLog(@"Animation operation finished");
}

- (void)userWillPanMapView:(TSClusterMapView *)mapView {
    
    NSLog(@"Map will pan from user interaction");
}

- (void)userDidPanMapView:(TSClusterMapView *)mapView {
    
    NSLog(@"Map did pan from user interaction");
}

- (BOOL)mapView:(TSClusterMapView *)mapView shouldForceSplitClusterAnnotation:(ADClusterAnnotation *)clusterAnnotation {
    
    return YES;
}

- (BOOL)mapView:(TSClusterMapView *)mapView shouldRepositionAnnotations:(NSArray<ADClusterAnnotation *> *)annotations toAvoidClashAtCoordinate:(CLLocationCoordinate2D)coordinate {
    
    return YES;
}

#pragma mark - Tab Bar Delegate

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    
    if (_tabBar.selectedItem == _bathroomTabBarItem) {
        _stepper.value = _bathroomAnnotationsAdded.count;
        _stepper.minimumValue = 0;
        _stepper.maximumValue = _bathroomAnnotations.count;
    }
    else if (_tabBar.selectedItem == _streetLightsTabBarItem) {
        _stepper.value = _streetLightAnnotationsAdded.count;
        _stepper.minimumValue = 0;
        _stepper.maximumValue = _streetLightAnnotations.count;
    }
}


#pragma mark - Controls

- (IBAction)addAll:(id)sender {
    
    if (_tabBar.selectedItem == _bathroomTabBarItem) {
        NSLog(@"Adding All %@", CDToiletJsonFile);
        
        [_mapView addClusteredAnnotations:_bathroomAnnotations toTree:CDToiletJsonFile];
        _bathroomAnnotationsAdded = [NSMutableArray arrayWithArray:_bathroomAnnotations];
        _stepper.value = _bathroomAnnotationsAdded.count;
    }
    else if (_tabBar.selectedItem == _streetLightsTabBarItem) {
        NSLog(@"Adding All %@", CDStreetLightJsonFile);
        
        [_mapView addClusteredAnnotations:_streetLightAnnotations toTree:CDStreetLightJsonFile];
        _streetLightAnnotationsAdded = [NSMutableArray arrayWithArray:_streetLightAnnotations];
        _stepper.value = _streetLightAnnotationsAdded.count;
    }
    
    [self refreshBadges];
}

- (IBAction)removeAll:(id)sender {
    
    if (_tabBar.selectedItem == _bathroomTabBarItem) {
        [_mapView removeAnnotations:_bathroomAnnotationsAdded fromTree:CDToiletJsonFile];
        [_bathroomAnnotationsAdded removeAllObjects];
        
        NSLog(@"Removing All %@", CDToiletJsonFile);
    }
    else if (_tabBar.selectedItem == _streetLightsTabBarItem) {
        [_mapView removeAnnotations:_streetLightAnnotationsAdded fromTree:CDStreetLightJsonFile];
        [_streetLightAnnotationsAdded removeAllObjects];
        
        NSLog(@"Removing All %@", CDStreetLightJsonFile);
    }
    
    [self refreshBadges];
}

- (IBAction)stepperValueChanged:(id)sender {
    
    if (_tabBar.selectedItem == _bathroomTabBarItem) {
        
        if (_stepper.value >= _bathroomAnnotationsAdded.count) {
            [self addNewBathroom];
        }
        else {
            [self removeLastBathroom];
        }
        _stepper.maximumValue = _bathroomAnnotations.count;
        _stepper.value = _bathroomAnnotationsAdded.count;
    }
    else if (_tabBar.selectedItem == _streetLightsTabBarItem) {
        if (_stepper.value >= _streetLightAnnotationsAdded.count) {
            [self addNewStreetLight];
        }
        else {
            [self removeLastStreetLight];
        }
        _stepper.maximumValue = _streetLightAnnotations.count;
        _stepper.value = _streetLightAnnotationsAdded.count;
    }
    
    [self refreshBadges];
}

- (void)refreshBadges {
    
    _bathroomTabBarItem.badgeValue = [NSString stringWithFormat:@"%lu", (unsigned long)_bathroomAnnotationsAdded.count];
    _streetLightsTabBarItem.badgeValue = [NSString stringWithFormat:@"%lu", (unsigned long)_streetLightAnnotationsAdded.count];
}

- (void)addNewBathroom {
    
    if (_bathroomAnnotationsAdded.count >= _bathroomAnnotations.count) {
        return;
    }
    
    NSLog(@"Adding 1 %@", CDToiletJsonFile);
    
    TSBathroomAnnotation *annotation = [_bathroomAnnotations objectAtIndex:_bathroomAnnotationsAdded.count];
    [_bathroomAnnotationsAdded addObject:annotation];
    
    [_mapView addClusteredAnnotation:annotation toTree:CDToiletJsonFile];
}

- (void)addNewStreetLight {
    
    if (_streetLightAnnotationsAdded.count >= _streetLightAnnotations.count) {
        return;
    }
    
    NSLog(@"Adding 1 %@", CDStreetLightJsonFile);
    
    TSStreetLightAnnotation *annotation = [_streetLightAnnotations objectAtIndex:_streetLightAnnotationsAdded.count];
    [_streetLightAnnotationsAdded addObject:annotation];
    
    [_mapView addClusteredAnnotation:annotation toTree:CDStreetLightJsonFile];
}

- (void)removeLastBathroom {
    
    NSLog(@"Removing 1 %@", CDToiletJsonFile);
    
    TSBathroomAnnotation *annotation = [_bathroomAnnotationsAdded lastObject];
    [_bathroomAnnotationsAdded removeObject:annotation];
    [_mapView removeAnnotation:annotation fromTree:CDToiletJsonFile];
}

- (void)removeLastStreetLight {
    
    NSLog(@"Removing 1 %@", CDStreetLightJsonFile);
    
    TSStreetLightAnnotation *annotation = [_streetLightAnnotationsAdded lastObject];
    [_streetLightAnnotationsAdded removeObject:annotation];
    [_mapView removeAnnotation:annotation fromTree:CDStreetLightJsonFile];
}

- (IBAction)segmentedControlValueChanged:(id)sender {
    
    switch (_segmentedControl.selectedSegmentIndex) {
        case 0:
            _mapView.clusterEdgeBufferSize = ADClusterBufferNone;
            break;
            
        case 1:
            _mapView.clusterEdgeBufferSize = ADClusterBufferSmall;
            break;
            
        case 2:
            _mapView.clusterEdgeBufferSize = ADClusterBufferMedium;
            break;
            
        case 3:
            _mapView.clusterEdgeBufferSize = ADClusterBufferLarge;
            break;
            
        default:
            break;
    }
}

- (IBAction)sliderValueChanged:(id)sender {
    
    _mapView.clusterPreferredVisibleCount = roundf(_slider.value);
    _label.text = [NSString stringWithFormat:@"%lu", (unsigned long)_mapView.clusterPreferredVisibleCount];
}

- (void)parseJsonData {
    
    _streetLightAnnotations = [[NSMutableArray alloc] initWithCapacity:10];
    _bathroomAnnotations = [[NSMutableArray alloc] initWithCapacity:10];
    _streetLightAnnotationsAdded = [[NSMutableArray alloc] initWithCapacity:10];
    _bathroomAnnotationsAdded = [[NSMutableArray alloc] initWithCapacity:10];
    NSLog(@"Loading data…");
    
    [[NSOperationQueue new] addOperationWithBlock:^{
        NSData * JSONData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:CDStreetLightJsonFile ofType:@"json"]];
        
        for (NSDictionary * annotationDictionary in [NSJSONSerialization JSONObjectWithData:JSONData options:kNilOptions error:NULL]) {
            TSStreetLightAnnotation * annotation = [[TSStreetLightAnnotation alloc] initWithDictionary:annotationDictionary];
            [_streetLightAnnotations addObject:annotation];
        }
        
        NSLog(@"Finished CDStreetLightJsonFile");
    }];
    
    [[NSOperationQueue new] addOperationWithBlock:^{
        NSData * JSONData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:CDToiletJsonFile ofType:@"json"]];
        
        for (NSDictionary * annotationDictionary in [NSJSONSerialization JSONObjectWithData:JSONData options:kNilOptions error:NULL]) {
            TSBathroomAnnotation * annotation = [[TSBathroomAnnotation alloc] initWithDictionary:annotationDictionary];
            [_bathroomAnnotations addObject:annotation];
        }
        
        NSLog(@"Finished CDToiletJsonFile");
    }];
}


- (void)kdTreeLoadingProgress:(NSNotification *)notification {
    NSNumber *number = [notification object];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _progressView.progress = number.floatValue;
    }];
}

@end

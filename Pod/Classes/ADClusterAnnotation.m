//
//  ADClusterAnnotation.m
//  AppLibrary
//
//  Created by Patrick Nollet on 01/07/11.
//  Copyright 2011 Applidium. All rights reserved.
//

#import "ADClusterAnnotation.h"
#import "TSRefreshedAnnotationView.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:(v) options:NSNumericSearch] != NSOrderedAscending)

@implementation ADClusterAnnotation

- (id)init {
    self = [super init];
    if (self) {
        _cluster = nil;
        self.coordinate = [self offMapCoordinate];
        _shouldBeRemovedAfterAnimation = NO;
        _title = @"Title";
    }
    return self;
}

- (void)setCluster:(ADMapCluster *)cluster {
    
    if (cluster && cluster!=_cluster) {
        _needsRefresh = YES;
    }
    else {
        _needsRefresh = NO;
    }
    
    _cluster = cluster;
}

- (NSString *)title {
    return self.cluster.title;
}

- (NSString *)subtitle {
    return self.cluster.subtitle;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    
    _coordinate = coordinate;
    self.coordinatePreAnimation = kCLLocationCoordinate2DInvalid;
}

- (void)reset {
    self.cluster = nil;
    self.coordinate = [self offMapCoordinate];
}

- (void)shouldReset {
    self.cluster = nil;
    self.coordinatePreAnimation = [self offMapCoordinate];
}

- (CLLocationCoordinate2D)offMapCoordinate {
    
    CLLocationCoordinate2D coordinate;// = CLLocationCoordinate2DMake(MAXFLOAT, MAXFLOAT);
    
//    if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        coordinate = CLLocationCoordinate2DMake(85.0, 179.0);
        // this coordinate puts the annotation on the top right corner of the map. We use this instead of kCLLocationCoordinate2DInvalid so that we don't mess with MapKit's KVO weird behaviour that removes from the map the annotations whose coordinate was set to kCLLocationCoordinate2DInvalid.
//    }
    
    return coordinate;
}

- (BOOL)offMap {
    CLLocationCoordinate2D offMapCoordinate = [self offMapCoordinate];
    return (self.coordinate.latitude == offMapCoordinate.latitude && self.coordinate.longitude == offMapCoordinate.longitude);
}

- (NSSet <id<MKAnnotation>> *)originalAnnotations {
    NSAssert(self.cluster != nil, @"This annotation should have a cluster assigned!");
    return self.cluster.originalAnnotations;
}

- (NSUInteger)clusterCount {
    
    return _cluster.clusterCount;
}

- (ADClusterAnnotationType)type {
    
    if (!self.clusterCount) {
        return ADClusterAnnotationTypeUnknown;
    }
    
    if (self.clusterCount > 1) {
        return ADClusterAnnotationTypeCluster;
    }
    
    return ADClusterAnnotationTypeLeaf;
}


@end

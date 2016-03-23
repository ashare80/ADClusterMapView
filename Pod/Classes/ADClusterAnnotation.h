//
//  ADClusterAnnotation.h
//  AppLibrary
//
//  Created by Patrick Nollet on 01/07/11.
//  Copyright 2011 Applidium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "ADMapCluster.h"
#import "TSClusterAnnotationView.h"


typedef NS_ENUM(NSUInteger, ADClusterAnnotationType) {
	ADClusterAnnotationTypeUnknown = 0,
	ADClusterAnnotationTypeLeaf = 1,
	ADClusterAnnotationTypeCluster = 2
};

/**
 * Do not subclass or directly modify. This MKAnnotation is a wrapper to keep the annotation static during clustering.
 */
@interface ADClusterAnnotation : NSObject <MKAnnotation>

//MKAnnotation
@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;

@property (readonly, nonatomic) BOOL offMap;

/*!
 * @discussion Type of annotation, cluster or single.
 */
@property (readonly) ADClusterAnnotationType type;

/*!
 * @discussion Cluster tree of annotations.
 */
@property (nonatomic, weak) ADMapCluster *cluster;

/*!
 * @discussion Annotation wrapper to refresh during clustering.
 */
@property (nonatomic, weak) TSClusterAnnotationView *annotationView;

/*!
 * @discussion Set YES for cluster operation to remove after animating.
 */
@property (nonatomic) BOOL shouldBeRemovedAfterAnimation;

/*!
 * @discussion This array contains the MKAnnotation objects represented by this annotation
 */
@property (weak, nonatomic, readonly) NSSet <id<MKAnnotation>> * originalAnnotations;

/*!
 * @discussion Number of annotations represented by the annotation
 */
@property (nonatomic, readonly) NSUInteger clusterCount;

/*!
 * @discussion Needs to have the annotationView refreshed
 */
@property (nonatomic, assign) BOOL needsRefresh;

/**
 * @discussion Should animate scale to pop in onto map
 */
@property (nonatomic, assign) BOOL popInAnimation;

/**
 * @discussion Coordinate to position annotation before the animation begins
 */
@property (nonatomic) CLLocationCoordinate2D coordinatePreAnimation;

/**
 * @discussion Coordinate to position annotation after the animation ends
 */
@property (nonatomic) CLLocationCoordinate2D coordinatePostAnimation;

/**
 * @discussion Remove cluster and make available or reset after animation
 */
- (void)shouldReset;

/**
 * @discussion Remove cluster and move to off-screen position
 */
- (void)reset;

@end

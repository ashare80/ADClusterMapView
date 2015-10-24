//
//  ADMapCluster.h
//  ADClusterMapView
//
//  Created by Patrick Nollet on 27/06/11.
//  Copyright 2011 Applidium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "ADMapPointAnnotation.h"

@class TSClusterMapView;

@interface ADMapCluster : NSObject

typedef void(^KdtreeCompletionBlock)(ADMapCluster *mapCluster);

@property (nonatomic, strong) ADMapPointAnnotation *annotation;

@property (nonatomic, assign) CLLocationCoordinate2D clusterCoordinate;

@property (nonatomic, assign) MKMapRect mapRect;

@property (nonatomic, assign) BOOL showSubtitle;

@property (nonatomic, readonly) NSInteger depth;

@property (readonly) NSMutableArray <id<MKAnnotation>> *originalAnnotations;

@property (readonly) NSMutableArray <ADMapPointAnnotation *> *originalMapPointAnnotations;

@property (readonly) NSString *title;

@property (readonly) NSString *subtitle;

@property (assign, nonatomic, readonly) NSInteger clusterCount;

@property (readonly) NSArray <NSString *> *clusteredAnnotationTitles;

@property (readonly) NSArray <ADMapCluster *> *children;

@property (readonly) NSMutableSet <ADMapCluster *> *allChildClusters;

@property (weak, nonatomic) ADMapCluster *parentCluster;

@property (readonly) NSSet <ADMapCluster *> *clustersWithAnnotations;

@property (strong, nonatomic) NSString *clusterRootTreeIdentifier;

- (id)initWithRootClusters:(NSArray <ADMapCluster *>*)clusters;

- (ADMapCluster *)rootClusterForID:(NSString *)treeID;

/*!
 * @discussion Creates a KD-tree of clusters http://en.wikipedia.org/wiki/K-d_tree
 * @param annotations Set of ADMapPointAnnotation objects
 * @param mapView The ADClusterMapView that will send the delegate callback
 * @param completion A new ADMapCluster object.
 */
+ (ADMapCluster *)rootClusterForAnnotations:(NSSet <ADMapPointAnnotation *> *)annotations mapView:(TSClusterMapView *)mapView completion:(KdtreeCompletionBlock)completion ;


/*!
 * @discussion Creates a KD-tree of clusters http://en.wikipedia.org/wiki/K-d_tree
 * @param annotations Set of ADMapPointAnnotation objects
 * @param gamma Descrimination power
 * @param clusterTitle Title of cluster
 * @param showSubtitle A Boolean to show subtitle from titles of children
 * @param completion A new ADMapCluster object.
 */
+ (ADMapCluster *)rootClusterForAnnotations:(NSSet <ADMapPointAnnotation *> *)annotations centerWeight:(double)gamma title:(NSString *)clusterTitle showSubtitle:(BOOL)showSubtitle completion:(KdtreeCompletionBlock)completion ;

/*!
 * @discussion Adds a single map point annotation to an existing KD-tree map cluster root
 * @param mapView The ADClusterMapView that will send the delegate callback
 * @param mapPointAnnotation A single ADMapPointAnnotation object
 * @param completion Yes if tree was updated, NO if full root should be updated
 */
- (void)mapView:(TSClusterMapView *)mapView addAnnotation:(ADMapPointAnnotation *)mapPointAnnotation completion:(void(^)(BOOL added))completion;


/*!
 * @discussion Removes a single map point annotation to an existing KD-tree map cluster root
 * @param mapView The ADClusterMapView that will send the delegate callback
 * @param annotation A single ADMapPointAnnotation object
 * @param completion YES if tree was updated, NO if full root should be updated
 */
- (void)mapView:(TSClusterMapView *)mapView removeAnnotation:(id<MKAnnotation>)annotation completion:(void(^)(BOOL added))completion;;

/*!
 * @discussion Get a set number of children contained within a map rect
 * @param number Max number of children to be returned
 * @param mapRect The mapr ect to search within
 * @param annotationSizeRect Map rect containing the size of an annotation view at the current region
 * @param overlap If YES annotation view size will not be accounted and clusters will overlap
 * @return A set containing children found in the rect. May return less than specified or none depending on results.
 */
- (NSSet <ADMapCluster *> *)find:(NSInteger)N childrenInMapRect:(MKMapRect)mapRect annotationViewSize:(MKMapRect)annotationSizeRect allowOverlap:(BOOL)overlap;

/*!
 * @discussion Checks the receiver to see how many of the given rects contain coordinates of children
 * @param mapRects An NSSet of NSDictionary objects containing MKMapRect structs (Use NSDictionary+MKMapRect method)
 * @return Number of map rects containing coordinates of children
 */
- (NSUInteger)numberOfMapRectsContainingChildren:(NSSet <NSDictionary <NSString *, NSNumber *>*> *)mapRects;

/*!
 * @discussion Check the receiver to see if contains the given cluster within it's cluster children
 * @param mapCluster An ADMapCluster object
 * @return YES if receiver found cluster in children
 */
- (BOOL)isAncestorOf:(ADMapCluster *)mapCluster;

/*!
 * @discussion Check the receiver to see if contains the given annotation within it's cluster
 * @param annotation A clusterable MKAnnotation
 * @return YES if receiver found annotation in children
 */
- (BOOL)isRootClusterForAnnotation:(id<MKAnnotation>)annotation;

/*!
 * @discussion Finds the cluster object associated with the annotation
 * @param annotation A clustered MKAnnotation
 * @return The ADMapCluster object that contains the annotation
 */
- (ADMapCluster *)clusterForAnnotation:(id<MKAnnotation>)annotation;


/*!
 * @discussion Finds the children of the receiver that are contained in a set.
 * @param clusters The clusters that need to be sorted.
 * @return Set of clusters that are all children of the receiver.
 */
- (NSMutableSet <ADMapCluster *> *)findChildrenForClusterInSet:(NSSet <ADMapCluster *> *)clusters;


/*!
 * @discussion Finds the ancestor of the receiver that is included in a set. Assumes there will only be one.
 * @param clusters The clusters to search.
 * @return The cluster that is an ancestor of the receiver or nil if there are none.
 */
- (ADMapCluster *)findAncestorForClusterInSet:(NSSet <ADMapCluster *> *)clusters;

@end

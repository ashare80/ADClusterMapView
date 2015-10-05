//
//  ADClusterMapView.h
//  ADClusterMapView
//
//  Created by Patrick Nollet on 30/06/11.
//  Copyright 2011 Applidium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "ADMapCluster.h"
#import "ADClusterAnnotation.h"
#import "TSClusterAnnotationView.h"
#import "TSClusterAnimationOptions.h"

// Progress of cluster tree notification
extern NSString * const KDTreeClusteringProgress;

@class TSClusterMapView;
@protocol TSClusterMapViewDelegate <MKMapViewDelegate, UIGestureRecognizerDelegate>
@optional

/*!
 * @discussion Set the annotation view for clustered annotations. To take advantage of a refresh call during clustering return a subclass of TSClusteredAnnotationView
 * @param mapView The map view that requested the annotation view.
 * @param annotation The object representing the annotation that is about to be displayed.
 * @return The annotation view to display for the specified annotation or nil if you want to display a standard annotation view.
 */
- (MKAnnotationView *)mapView:(TSClusterMapView *)mapView viewForClusterAnnotation:(id <MKAnnotation>)annotation;

/*!
 * @discussion MapView will begin creating Kd-tree from new annotations. Use this delegate to alert the user of a refresh for large data sets with long build times.
 * @param mapView The map view that will begin clustering.
 */
- (void)mapView:(TSClusterMapView *)mapView willBeginBuildingClusterTreeForMapPoints:(NSSet *)annotations;

/*!
 * @discussion MapView did finish creating Kd-tree from new annotations. Remove any UI associated with loading annotations, cluster animation will begin.
 * @param mapView The map view that will begin clustering.
 */
- (void)mapView:(TSClusterMapView *)mapView didFinishBuildingClusterTreeForMapPoints:(NSSet *)annotations;

/*!
 * @discussion Animation operation will begin for mapView. Follows a mapView:regionDidChangeAnimated: or mapViewDidFinishBuildingClusterTree. Operation may cancel before finishing from new clustering parameters.
 * @param mapView The map view that will begin clustering.
 */
- (void)mapViewWillBeginClusteringAnimation:(TSClusterMapView *)mapView;

/*!
 * @discussion Animation operation was cancelled due to map movement or new tree.
 * @param mapView The map view that did cancel clustering.
 */
- (void)mapViewDidCancelClusteringAnimation:(TSClusterMapView *)mapView;

/*!
 * @discussion Animation operation did finish successfully.
 * @param mapView The map view that did finish clustering.
 */
- (void)mapViewDidFinishClusteringAnimation:(TSClusterMapView *)mapView;

/*!
 * @discussion Convenience delegate to determine if map will pan by user gesture
 * @param mapView The map view that will begin panning.
 */
- (void)userWillPanMapView:(TSClusterMapView *)mapView;
/*!
 * @discussion Convenience delegate to determine if map did pan by user gesture
 * @param mapView The map view that did finish panning.
 */
- (void)userDidPanMapView:(TSClusterMapView *)mapView;

@end


/*!
 * @discussion Using None will tell the operation to make clustering decisions based only on the visible region of the map. Large will add a full screen size in all directions to the region to cluster creating more accurate results.
 */
typedef NS_ENUM(NSInteger, ADClusterBufferSize) {
    ADClusterBufferNone = 0,
    ADClusterBufferSmall = 2,
    ADClusterBufferMedium = 4,
    ADClusterBufferLarge = 8
};

@interface TSClusterMapView : MKMapView <MKMapViewDelegate, UIGestureRecognizerDelegate, TSClusterMapViewDelegate>

/*!
 * @discussion Adds an annotation to the map and clusters if needed (threadsafe). Only rebuilds entire cluster tree if there are less than 1000 clustered annotations or the annotation coordinate is an outlier from current clustered data set.
 * @param annotation The annotation to be added to map
 */
- (void)addClusteredAnnotation:(id<MKAnnotation>)annotation;

/*!
 * @discussion Adds multiple annotations to the map and clusters if needed (threadsafe). Rebuilds entire cluster tree.
 * @param annotations The array of MKAnnotation objects to be added to map
 */
- (void)addClusteredAnnotations:(NSArray *)annotations;

/*!
 * @discussion Add annotation with option to force a full tree refresh (threadsafe).
 * @param annotation The MKAnnotation to be added to map
 * @param refresh A Boolean that specifies whether the cluster tree should rebuild or quickly insert into existing tree. Cluster tree refresh can cause a delay with large data sets but provides more accurate clustering.
 */
- (void)addClusteredAnnotation:(id<MKAnnotation>)annotation clusterTreeRefresh:(BOOL)refresh;

/*!
 * @discussion Remove all annotations from the map view.  No refresh is performed because all annotations are removed.
 */
- (void)removeAllAnnotations;

/*!
 * @discussion Force a refresh of clustering tree.
 */
- (void)needsRefresh;

/*!
 * @discussion Asks delegate for a new MKAnnotationView. Used before cluster animation to update annotation views.
 * @param annotation The annotation that needs to be refreshed.
 */
- (void)refreshClusterAnnotation:(ADClusterAnnotation *)annotation;

/*!
 * @discussion Finds the cluster visible on the map that contains a single annotation
 * @param annotation The annotation that was added to the map view.
 * @return The visible ADClusterAnnotation instance containing the annotation originally added.
 */
- (ADClusterAnnotation *)currentClusterAnnotationForAddedAnnotation:(id<MKAnnotation>)annotation;

#pragma mark - Properties

/*!
 * @discussion Visible cluster annotations. Will contain clusters just outside visible rect included in buffer zone.
 */
@property (readonly) NSArray * visibleClusterAnnotations;

/*!
 * @discussion Suggested number of clusterable annotations visible at once. More may be visible if buffer size not set to none. Less will be visible if clusters overlap.  Default: 20
 */
@property (assign, nonatomic) NSUInteger clusterPreferredVisibleCount;

/*!
 * @discussion Creates a buffer zone surrounding visible map of clustered annotations. This helps simulate seemless loading of annotations and helps prevent annotations from appearing and dissapearing close to the edge. NOTE: For older devices or larger data sets try reducing the buffer size Default: ADClusterBufferMedium
 */
@property (assign, nonatomic) ADClusterBufferSize clusterEdgeBufferSize;

/*!
 * @discussion This parameter emphasize the discrimination of annotations which are far away from the center of mass. Could result in cluster tree mapping times doubling. Default: 0.0 (no discrimination applied) Max:1.0
 */
@property (assign, nonatomic) float clusterDiscrimination;

/*!
 * @discussion Cluster annotation creates subtitle from list of contained titles. Default: YES
 */
@property (assign, nonatomic) BOOL clusterShouldShowSubtitle;

/**
 Title for cluster annotations. Default: @"%d elements"
 */
@property (strong, nonatomic) NSString *clusterTitle;

/**
 If cluster annotation is selected it zooms in to show contents instead of a callout. Default: YES
 */
@property (assign, nonatomic) BOOL clusterZoomsOnTap;

/**
 If YES any new clusters that need to be shown that don't have a previous location to animate from will appear with a scale animation.
 */
@property (assign, nonatomic) BOOL clusterAppearanceAnimated;

/**
 UIView animation block parameters for the clustering animations.
 */
@property (strong, nonatomic) TSClusterAnimationOptions *clusterAnimationOptions;

/**
 Will be automatically calculated after setting delegate from mapView:viewForClusterAnnotation: if available. Cluster animation will try to eliminate annotation overlaps using this size.
 */
@property (assign, nonatomic) CGSize clusterAnnotationViewSize;


/**
 Turn on delegate call userDidPanMapView:
 */
@property (assign, nonatomic) BOOL monitorMapPan;


@end
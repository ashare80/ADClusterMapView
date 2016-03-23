//
//  TSClusterOperation.m
//  TapShield
//
//  Created by Adam Share on 7/14/14.
//  Copyright (c) 2014 TapShield, LLC. All rights reserved.
//

#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#import "TSClusterOperation.h"
#import <MapKit/MapKit.h>
#import "ADMapCluster.h"
#import "ADClusterAnnotation.h"
#import "ADMapPointAnnotation.h"
#import "NSDictionary+MKMapRect.h"
#import "CLLocation+Utilities.h"
#import "TSClusterMapView.h"
#import "TSRefreshedAnnotationView.h"

@interface AwaitingMatch : NSObject
@property (nonatomic, strong) ADMapCluster *cluster;
@property (nonatomic, strong) ADClusterAnnotation *annotation;
@end

@implementation AwaitingMatch
@end

@interface TSClusterOperation ()

@property (weak, nonatomic) TSClusterMapView *mapView;
@property (strong, nonatomic) ADMapCluster *rootMapCluster;

@property (assign, nonatomic) NSUInteger numberOfClusters;
@property (assign, nonatomic) MKMapRect clusteringRect;
@property (nonatomic, strong) NSMutableSet <ADClusterAnnotation *> *annotationPool;
@property (nonatomic, strong) NSMutableSet <ADClusterAnnotation *> *poolAnnotationRemoval;

@property (nonatomic, readonly) NSSet <ADClusterAnnotation *>* unmatchedOffMapAnnotations;
@property (nonatomic, readonly) NSSet <ADClusterAnnotation *>* unmatchedAnnotations;
@property (nonatomic, readonly) NSSet <ADClusterAnnotation *>* matchedAnnotations;
@property (nonatomic, readonly) NSMutableSet <ADMapCluster *>* parentClustersMatched;

@property (nonatomic, strong) NSMutableSet <ADClusterAnnotation *> *removeAfterAnimation;

@property (nonatomic, strong) ADMapCluster *splitCluster;

@end

@implementation TSClusterOperation


- (void)main {
    
    @autoreleasepool {
        
        if (_splitCluster) {
            [self splitSingleCluster:_splitCluster];
        }
        else {
            [self clusterInMapRect:_clusteringRect];
        }
    }
}

#pragma mark - Initializers

+ (instancetype)mapView:(TSClusterMapView *)mapView rect:(MKMapRect)rect rootCluster:(ADMapCluster *)rootCluster showNumberOfClusters:(NSUInteger)numberOfClusters clusterAnnotations:(NSSet <ADClusterAnnotation *> *)clusterAnnotations completion:(ClusterOperationCompletionBlock)completion {
    
    return [[TSClusterOperation alloc] initWithMapView:mapView
                                                  rect:rect
                                           rootCluster:rootCluster
                                  showNumberOfClusters:numberOfClusters
                                    clusterAnnotations:clusterAnnotations
                                            completion:completion];
}

- (instancetype)initWithMapView:(TSClusterMapView *)mapView rect:(MKMapRect)rect rootCluster:(ADMapCluster *)rootCluster showNumberOfClusters:(NSUInteger)numberOfClusters clusterAnnotations:(NSSet <ADClusterAnnotation *> *)clusterAnnotations completion:(ClusterOperationCompletionBlock)completion
{
    self = [super init];
    if (self) {
        self.mapView = mapView;
        self.rootMapCluster = rootCluster;
        self.finishedBlock = completion;
        self.annotationPool = [clusterAnnotations copy];
        self.numberOfClusters = numberOfClusters;
        self.clusteringRect = rect;
    }
    return self;
}

+ (instancetype)mapView:(TSClusterMapView *)mapView splitCluster:(ADMapCluster *)splitCluster clusterAnnotationsPool:(NSSet <ADClusterAnnotation *> *)clusterAnnotations {
    
    return [[TSClusterOperation alloc] initWithMapView:mapView
                                          splitCluster:splitCluster
                                    clusterAnnotations:clusterAnnotations];
}

- (instancetype)initWithMapView:(TSClusterMapView *)mapView splitCluster:(ADMapCluster *)splitCluster clusterAnnotations:(NSSet <ADClusterAnnotation *> *)clusterAnnotations
{
    self = [super init];
    if (self) {
        self.mapView = mapView;
        self.splitCluster = splitCluster;
        self.annotationPool = [clusterAnnotations copy];
    }
    return self;
}

#pragma mark - Annotation Groups

- (NSSet <ADClusterAnnotation *>*)unmatchedOffMapAnnotations {
    
    NSMutableSet *offMapAnnotations = [[NSMutableSet alloc] initWithCapacity:_annotationPool.count];
    for (ADClusterAnnotation *annotation in _annotationPool) {
        if (annotation.offMap && !annotation.cluster) {
            [offMapAnnotations addObject:annotation];
        }
    }
    
    return offMapAnnotations;
}

- (NSSet <ADClusterAnnotation *>*)unmatchedAnnotations {
    
    NSMutableSet *unmatchedAnnotations = [[NSMutableSet alloc] initWithCapacity:_annotationPool.count];
    for (ADClusterAnnotation *annotation in _annotationPool) {
        if (!annotation.cluster) {
            [unmatchedAnnotations addObject:annotation];
        }
    }
    return unmatchedAnnotations;
}

- (NSSet <ADClusterAnnotation *>*)matchedAnnotations {
    
    NSMutableSet *matchedAnnotations = [[NSMutableSet alloc] initWithSet:_annotationPool];
    [matchedAnnotations minusSet:self.unmatchedAnnotations];
    
    return matchedAnnotations;
}

- (NSMutableSet <AwaitingMatch *> *)matchChildren:(NSSet <ADMapCluster *> *)children annotation:(ADClusterAnnotation *)annotation {
    
    NSMutableSet *childrenToMatch = [children mutableCopy];
    NSMutableSet <AwaitingMatch *> *stillNeedsMatch = [[NSMutableSet alloc] initWithCapacity:children.count];
    //Choose any child cluster that needs to be shown and assign it to the existing annotation so that it stays on the map and moves to the new location to represent the child cluster
    ADMapCluster *cluster = [children anyObject];
    annotation.cluster = cluster;
    annotation.coordinatePreAnimation = annotation.coordinate;
    [childrenToMatch removeObject:cluster];
    
    //There should be more than one child if it splits so we'll need to grab unused annotations.
    //Clusterless offMap annotations will then start at the annotation on screen's point and split to the child coordinate.
    
    NSMutableSet *offMap = [self.unmatchedOffMapAnnotations mutableCopy];
    for (ADMapCluster *cluster in childrenToMatch) {
        ADClusterAnnotation *clusterlessAnnotation = [offMap anyObject];
        if (clusterlessAnnotation) {
            [offMap removeObject:clusterlessAnnotation];
            clusterlessAnnotation.cluster = cluster;
            clusterlessAnnotation.coordinatePreAnimation = annotation.coordinate;
        }
        else {
            //Ran out of annotations off screen we'll come back after more have been sorted and reassign one that is available
            AwaitingMatch *unmatched = [[AwaitingMatch alloc] init];
            unmatched.cluster = cluster;
            unmatched.annotation = annotation;
            [stillNeedsMatch addObject:unmatched];
        }
    }
    
    //Returns the children that couldn't be matched do to not enough available annotations at the time
    return stillNeedsMatch;
}

- (ADMapCluster *)matchedClusterForAnnotation:(ADClusterAnnotation *)annotation inSet:(NSSet <ADMapCluster *>*)clustersToShowOnMap {
    
    ADMapCluster *cluster = [annotation.cluster findAncestorForClusterInSet:clustersToShowOnMap];
    
    //Found an ancestor
    //These will start as individual annotations and converge into a single annotation during animation
    if (cluster) {
        annotation.cluster = cluster;
        annotation.coordinatePreAnimation = annotation.coordinate;
        
        if ([_parentClustersMatched containsObject:cluster]) {
            [_removeAfterAnimation addObject:annotation];
        }
        
        [_parentClustersMatched addObject:cluster];
        return cluster;
    }
    
    return cluster;
}

/**
 If there are available nearby, set the available annotation to animate to cluster position and take over. After a full tree refresh all annotations will be unmatched but coordinates still may match up or be close by.
*/
- (void)matchLeftoverOnscreenAnnotations:(NSMutableSet <ADMapCluster *> *)unMatchedClusters {
    
    for (ADMapCluster *cluster in [unMatchedClusters copy]) {
        ADClusterAnnotation *annotation;
        
        MKMapRect mRect = _mapView.visibleMapRect;
        MKMapPoint eastMapPoint = MKMapPointMake(MKMapRectGetMinX(mRect), MKMapRectGetMidY(mRect));
        MKMapPoint westMapPoint = MKMapPointMake(MKMapRectGetMaxX(mRect), MKMapRectGetMidY(mRect));
        //Don't want annotations flying across the map
        CLLocationDistance min = MKMetersBetweenMapPoints(eastMapPoint, westMapPoint)/2;
        
        NSMutableSet <ADClusterAnnotation *> *unmatchedOnScreen = [NSMutableSet setWithSet:self.unmatchedAnnotations];
        [unmatchedOnScreen minusSet:self.unmatchedOffMapAnnotations ];
        for (ADClusterAnnotation *checkAnnotation in unmatchedOnScreen) {
            
            //Could be same
            if (CLLocationCoordinate2DIsApproxEqual(checkAnnotation.coordinate, cluster.clusterCoordinate, 0.00001)) {
                annotation = checkAnnotation;
                break;
            }
            
            //Find closest
            CLLocationDistance distance = MKMetersBetweenMapPoints(MKMapPointForCoordinate(checkAnnotation.coordinate),
                                                                   MKMapPointForCoordinate(cluster.clusterCoordinate));
            if (distance < min) {
                min = distance;
                annotation = checkAnnotation;
            }
        }
        
        if (annotation) {
            annotation.coordinatePreAnimation = annotation.coordinate;
            annotation.popInAnimation = NO;
            //already visible don't animate appearance
        }
        else if (self.unmatchedOffMapAnnotations.count) {
            annotation = [self.unmatchedOffMapAnnotations anyObject];
            annotation.coordinatePreAnimation = cluster.clusterCoordinate;
            annotation.popInAnimation = YES;
            //Not visible animate appearance
        }
        else {
            //NSLog(@"Not enough annotations?!");
            break;
        }
        
        annotation.cluster = cluster;
        [unMatchedClusters removeObject:cluster];
    }
}

#pragma mark - Full Cluster Operation

- (NSSet<ADMapCluster *> *)clustersToShowOnMap:(MKMapRect)clusteredMapRect {
    
    NSUInteger maxNumberOfClusters = _numberOfClusters;
    
    MKMapRect annotationViewSize = [self mapRectAnnotationViewSize];
    
    //If there is no size available to the clustering operation use a grid to keep from cluttering
    if (MKMapRectIsEmpty(annotationViewSize)) {
        maxNumberOfClusters = [self calculateNumberByGrid:clusteredMapRect];
    }
    
    BOOL shouldOverlap = NO;//(_mapView.camera.altitude <= 400);
    
    //Try and account for camera pitch which distorts clustering calculations
    if (_mapView.camera.pitch > 50) {
        shouldOverlap = YES;
        clusteredMapRect = _mapView.visibleMapRect;
    }
    
    return [_rootMapCluster find:maxNumberOfClusters childrenInMapRect:clusteredMapRect annotationViewSize:annotationViewSize allowOverlap:shouldOverlap];
}

- (void)clusterInMapRect:(MKMapRect)clusteredMapRect {
    
    //NSLog(@"1 %@", [NSOperationQueue currentQueue].name);
    
    if (!_rootMapCluster.clusterCount) {
        [self resetAll];
        return;
    }
    
    //Clusters that need to be visible after the animation
    NSSet *clustersToShowOnMap = [self clustersToShowOnMap:clusteredMapRect];
    
    //NSLog(@"2 %@", [NSOperationQueue currentQueue].name);
    
    if (self.isCancelled) {
        if (_finishedBlock) {
            _finishedBlock(clusteredMapRect, NO, nil);
        }
        return;
    }
    
    
    //Begin with all clusters to show on the map
    NSMutableSet <ADMapCluster *> *unMatchedClusters = [[NSMutableSet alloc] initWithSet:clustersToShowOnMap];
    
    //There will be only one annotation after clustering in so we want to know if the parent cluster was already matched to an annotation
    _parentClustersMatched = [[NSMutableSet alloc] initWithCapacity:_numberOfClusters];
    
    
    //These will be the annotations that converge to a point and will no longer be needed
    _removeAfterAnimation = [[NSMutableSet alloc] initWithCapacity:_numberOfClusters];
    
    //These will be leftovers that didn't have any annotations available to match at the time.
    //Some annotations should become free after further sorting and matching.
    //At the end any unmatched annotations will be used.
    NSMutableSet <AwaitingMatch *> *stillNeedsMatch = [[NSMutableSet alloc] initWithCapacity:10];
    
    //Go through annotations that already have clusters and try and match them to new clusters
    for (ADClusterAnnotation *annotation in self.matchedAnnotations) {
        
        NSSet <ADMapCluster *> *children = [annotation.cluster findChildrenForClusterInSet:clustersToShowOnMap];
        
        if (children.count) {
            //Found children
            //These will start at cluster and split to their respective cluster coordinates
            NSSet *unmatchedChildren = [self matchChildren:children annotation:annotation];
            
            //Unmatched children will be paired later when more annotations become free
            [stillNeedsMatch unionSet:unmatchedChildren];
            [unMatchedClusters minusSet:children];
            continue;
        }
        
        
        ADMapCluster *cluster = [self matchedClusterForAnnotation:annotation inSet:clustersToShowOnMap];
        
        if (cluster) {
            //Found an ancestor
            //These will start as individual annotations and converge into a single annotation during animation
            [unMatchedClusters removeObject:cluster];
            continue;
        }
        
        //No ancestor or child found
        //This will happen when the annotation is no longer in the visible map rect and
        //the section of the cluster tree does not include this annotation
        [annotation shouldReset];
    }
    
    
    //NSLog(@"3 %@", [NSOperationQueue currentQueue].name);
    //Find annotations for remaining unmatched clusters
    [self matchLeftoverOnscreenAnnotations:unMatchedClusters];
    
    //NSLog(@"4 %@", [NSOperationQueue currentQueue].name);
    //Still need unmatched for a split into multiple from cluster
    if (stillNeedsMatch.count) {
        for (AwaitingMatch *awaitingMatch in stillNeedsMatch) {
            ADClusterAnnotation *clusterlessAnnotation = [self.unmatchedAnnotations anyObject];
            
            if (clusterlessAnnotation) {
                clusterlessAnnotation.cluster = awaitingMatch.cluster;
                clusterlessAnnotation.coordinatePreAnimation = awaitingMatch.annotation.coordinate;
            }
            else {
                [unMatchedClusters addObject:awaitingMatch.cluster];
            }
        }
    }
    
    if (unMatchedClusters.count) {
        NSLog(@"Unmatched Clusters!?");
    }
    
    //NSLog(@"5 %@", [NSOperationQueue currentQueue].name);
    
    for (ADClusterAnnotation * annotation in _annotationPool) {
        if (annotation.cluster) {
            annotation.coordinatePostAnimation = annotation.cluster.clusterCoordinate;
        }
    }
    
    //Create a circle around coordinate to display all single annotations that overlap
    [self mutateCoordinatesOfClashingAnnotations:self.matchedAnnotations];
    
    ADClusterAnnotation *annotationToSelect = [self annotationToSelect];
    
    //NSLog(@"6 %@", [NSOperationQueue currentQueue].name);
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self executeAnimationAndSelectAnnotation:annotationToSelect];
    }];
}

- (ADClusterAnnotation *)annotationToSelect {
    ADClusterAnnotation *selectedAnnotation = [_mapView.selectedAnnotations firstObject];
    ADClusterAnnotation *annotationToSelect;
    
    
    if (selectedAnnotation && [selectedAnnotation isKindOfClass:[ADClusterAnnotation class]]) {
        for (ADClusterAnnotation *annotation in self.matchedAnnotations) {
            if (annotation.cluster == selectedAnnotation.cluster || [annotation.cluster isAncestorOf:selectedAnnotation.cluster]) {
                annotationToSelect = annotation;
                break;
            }
            
            if ((annotation.type == ADClusterAnnotationTypeCluster &&
                 CLLocationCoordinate2DIsApproxEqual(annotation.coordinate, selectedAnnotation.coordinate, .000001)) ||
                ![_removeAfterAnimation containsObject:annotation]) {
                annotationToSelect = annotation;
            }
        }
    }
    
    //Don't select if cluster is outside visible region and would move map
    if (!MKMapRectContainsPoint(_mapView.visibleMapRect, MKMapPointForCoordinate(annotationToSelect.coordinate))) {
        annotationToSelect = nil;
    }
    
    //Don't select if cluster would zoom after selection
    if (annotationToSelect.type == ADClusterAnnotationTypeCluster && _mapView.clusterZoomsOnTap) {
        annotationToSelect = nil;
    }
    
    return annotationToSelect;
}

- (void)executeAnimationAndSelectAnnotation:(ADClusterAnnotation *)annotationToSelect {
    
    NSArray *selectedAnnotations = _mapView.selectedAnnotations;
    ADClusterAnnotation *selectedAnnotation = [selectedAnnotations firstObject];
    
    //Make sure they are in the offMap position
    for (ADClusterAnnotation *annotation in self.unmatchedAnnotations) {
        [annotation reset];
    }
    
    //Make sure we close callout of cluster if needed
    for (ADClusterAnnotation *annotation in selectedAnnotations) {
        if ([annotation isKindOfClass:[ADClusterAnnotation class]]) {
            if ((annotation.type == ADClusterAnnotationTypeCluster &&
                 !CLLocationCoordinate2DIsApproxEqual(annotation.coordinate, annotation.coordinatePreAnimation, .000001)) ||
                [_removeAfterAnimation containsObject:annotation]) {
                [_mapView deselectAnnotation:annotation animated:NO];
            }
        }
    }
    
    //Set pre animation position
    for (ADClusterAnnotation *annotation in _annotationPool) {
        if (CLLocationCoordinate2DIsValid(annotation.coordinatePreAnimation)) {
            annotation.coordinate = annotation.coordinatePreAnimation;
        }
    }
    
    
    for (ADClusterAnnotation * annotation in _annotationPool) {
        //Get the new or cached view from delegate
        if (annotation.cluster && annotation.needsRefresh) {
            [_mapView refreshClusterAnnotation:annotation];
        }
        
        //Pre animation setup for popInAnimation
        if (annotation.popInAnimation && _mapView.clusterAppearanceAnimated) {
            CGAffineTransform t = CGAffineTransformMakeScale(0.001, 0.001);
            t = CGAffineTransformTranslate(t, 0, -annotation.annotationView.frame.size.height);
            annotation.annotationView.transform  = t;
        }
    }
    
    //Selected if needed
    if (annotationToSelect) {
        [_mapView selectAnnotation:annotationToSelect animated:YES];
    }
    else if (selectedAnnotation) {
        [_mapView deselectAnnotation:selectedAnnotation animated:NO];
    }
    
    TSClusterAnimationOptions *options = _mapView.clusterAnimationOptions;
    [UIView animateWithDuration:options.duration delay:0.0 usingSpringWithDamping:options.springDamping initialSpringVelocity:options.springVelocity options:options.viewAnimationOptions animations:^{
        for (ADClusterAnnotation * annotation in _annotationPool) {
            if (annotation.cluster) {
                annotation.coordinate = annotation.coordinatePostAnimation;
                [annotation.annotationView animateView];
            }
            if (annotation.popInAnimation && _mapView.clusterAppearanceAnimated) {
                annotation.annotationView.transform = CGAffineTransformIdentity;
                annotation.popInAnimation = NO;
            }
        }
    } completion:^(BOOL finished) {
        
        for (ADClusterAnnotation * annotation in _annotationPool) {
            if (annotation.cluster) {
                annotation.coordinate = annotation.coordinatePostAnimation;
                [annotation.annotationView animateView];
                annotation.annotationView.transform = CGAffineTransformIdentity;
                annotation.popInAnimation = NO;
            }
        }
        
        //Make sure selected if was previously offMap
        if (annotationToSelect) {
            [_mapView selectAnnotation:annotationToSelect animated:YES];
        }
        
        //Need to be removed after clustering they are no longer needed
        for (ADClusterAnnotation *annotation in _removeAfterAnimation) {
            [annotation reset];
        }
        
        //If the number of clusters wanted on screen was reduced we can adjust the annotation pool accordingly to speed things up
        NSSet *toRemove = [self poolAnnotationsToRemove:_numberOfClusters freeAnnotations:[self.unmatchedAnnotations setByAddingObjectsFromSet:_removeAfterAnimation]];
        
        if (_finishedBlock) {
            _finishedBlock(_clusteringRect, YES, toRemove);
        }
    }];
}

- (void)resetAll {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        for (ADClusterAnnotation *annotation in _annotationPool) {
            [annotation reset];
        }
    }];
}

#pragma mark - Split Operation

- (void)splitSingleCluster:(ADMapCluster *)cluster {
    
    NSMutableSet *unmatchedAnnotations = [[NSMutableSet alloc] initWithCapacity:_annotationPool.count];
    NSMutableSet *matchedAnnotations = [[NSMutableSet alloc] initWithCapacity:cluster.clusterCount];
    ADClusterAnnotation *currentAnnotation;
    
    for (ADClusterAnnotation *annotation in _annotationPool) {
        if (!annotation.cluster) {
            [unmatchedAnnotations addObject:annotation];
        }
        else if (annotation.cluster == cluster) {
            //This is the annotation already at the point to split
            currentAnnotation = annotation;
        }
    }
    
    //Cluster objects that represent the original annotations we'll split to
    NSSet *originalAnnotationClusters = cluster.clustersWithAnnotations;
    
    for (ADMapCluster *leafCluster in originalAnnotationClusters) {
        
        ADClusterAnnotation *annotation;
        if (currentAnnotation) {
            //Use the current annotation first to give it a position to move to.
            annotation = currentAnnotation;
            currentAnnotation = nil;
        }
        else {
            annotation = [unmatchedAnnotations anyObject];
            [unmatchedAnnotations removeObject:annotation];
        }
        
        annotation.cluster = leafCluster;
        annotation.coordinatePreAnimation = cluster.clusterCoordinate;
        
        [matchedAnnotations addObject:annotation];
    }
    
    for (ADClusterAnnotation * annotation in matchedAnnotations) {
        annotation.coordinatePostAnimation = annotation.cluster.clusterCoordinate;
    }
    
    //Create a circle around coordinate to display all single annotations that overlap
    [self mutateCoordinatesOfClashingAnnotations:matchedAnnotations];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        //Set pre animation position
        for (ADClusterAnnotation *annotation in matchedAnnotations) {
            if (CLLocationCoordinate2DIsValid(annotation.coordinatePreAnimation)) {
                annotation.coordinate = annotation.coordinatePreAnimation;
            }
        }
        
        
        for (ADClusterAnnotation * annotation in matchedAnnotations) {
            //Get the new or cached view from delegate
            [_mapView refreshClusterAnnotation:annotation];
        }
        
        TSClusterAnimationOptions *options = _mapView.clusterAnimationOptions;
        
        [UIView animateWithDuration:options.duration delay:0.0 usingSpringWithDamping:options.springDamping initialSpringVelocity:options.springVelocity options:options.viewAnimationOptions  animations:^{
            for (ADClusterAnnotation * annotation in matchedAnnotations) {
                annotation.coordinate = annotation.coordinatePostAnimation;
                if (annotation.cluster) {
                    [annotation.annotationView animateView];
                }
                
                if (annotation.popInAnimation && _mapView.clusterAppearanceAnimated) {
                    annotation.annotationView.transform = CGAffineTransformIdentity;
                    annotation.popInAnimation = NO;
                }
            }
        } completion:^(BOOL finished) {
            
        }];
    }];
}

#pragma mark - Helpers

- (NSSet <ADClusterAnnotation *> *)poolAnnotationsToRemove:(NSInteger)numberOfAnnotationsInPool freeAnnotations:(NSSet <ADClusterAnnotation *> *)annotations {
    
    NSInteger difference = _annotationPool.count - (numberOfAnnotationsInPool*2);
    
    if (difference > 0) {
        if (annotations.count >= difference) {
            return [NSSet setWithArray:[annotations.allObjects subarrayWithRange:NSMakeRange(0, difference)]];
        }
    }
    
    return nil;
}


#pragma mark - Annotation View Rect Conversions

- (MKMapRect)mapRectForRect:(CGRect)rect {
    if (CGRectIsEmpty(rect)) {
        return MKMapRectNull;
    }
    
    //Because the map could rotate and MKMapRect does not, create a triangle with coordinates to get height and width then
    //create the rect out of the height and width with a North South orientation.
    CLLocationCoordinate2D topLeft = [_mapView convertPoint:CGPointMake(rect.origin.x, rect.origin.y) toCoordinateFromView:_mapView];
    CLLocationCoordinate2D bottomRight = [_mapView convertPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)) toCoordinateFromView:_mapView];
    
    //Get Hypotenuse then calculate xA*xA + xB*xB = xC*xC = distance
    CLLocationDistance distance = MKMetersBetweenMapPoints(MKMapPointForCoordinate(topLeft), MKMapPointForCoordinate(bottomRight));
    double x = sqrt(distance*distance/(rect.size.width*rect.size.width + rect.size.height*rect.size.height));
    
    CLLocationCoordinate2D translated = [self translateCoord:topLeft MetersLat:-x*rect.size.height MetersLong:x*rect.size.width];
    
    MKMapPoint topLeftPoint = MKMapPointForCoordinate(topLeft);
    MKMapPoint bottomRightPoint = MKMapPointForCoordinate(translated);
    
    MKMapRect mapRect = MKMapRectMake(topLeftPoint.x, topLeftPoint.y, bottomRightPoint.x - topLeftPoint.x, bottomRightPoint.y - topLeftPoint.y);
    return mapRect;
}

- (CLLocationCoordinate2D)translateCoord:(CLLocationCoordinate2D)coord MetersLat:(double)metersLat MetersLong:(double)metersLong{
    
    CLLocationCoordinate2D tempCoord;
    
    MKCoordinateRegion tempRegion = MKCoordinateRegionMakeWithDistance(coord, metersLat, metersLong);
    MKCoordinateSpan tempSpan = tempRegion.span;
    
    tempCoord.latitude = coord.latitude + tempSpan.latitudeDelta;
    tempCoord.longitude = coord.longitude + tempSpan.longitudeDelta;
    
    return tempCoord;
    
}

- (CGRect)annotationViewRect {
    
    return CGRectMake(0, 0, _mapView.clusterAnnotationViewSize.width, _mapView.clusterAnnotationViewSize.height);
}

- (MKMapRect)mapRectAnnotationViewSize {
    
    return [self mapRectForRect:[self annotationViewRect]];
}

#pragma mark - Grid clusters

- (NSUInteger)calculateNumberByGrid:(MKMapRect)clusteredMapRect {
    
    //This will be used if the size is unknown for cluster annotationViews
    //Creates grid to estimate number of clusters needed based on the spread of annotations across map rect.
    //
    //If there are should be 20 max clusters, we create 20 even rects (plus buffer rects) within the given map rect
    //and search to see if a cluster is contained in that rect.
    //
    //This helps distribute clusters more evenly by limiting clusters presented relative to viewable region.
    //Zooming all the way out will then be able to cluster down to one single annotation if all clusters are within one grid rect.
    
    NSDate *date = [NSDate date];
    NSUInteger numberOnScreen = _numberOfClusters;
    
    if (_mapView.camera.altitude > 1000) {
        
        //Number of map rects that contain at least one annotation
        NSSet *mapRects = [self mapRectsFromMaxNumberOfClusters:_numberOfClusters mapRect:clusteredMapRect];
        
        date = [NSDate date];
        numberOnScreen = [_rootMapCluster numberOfMapRectsContainingChildren:mapRects];
        if (numberOnScreen < 1) {
            numberOnScreen = 1;
        }
    }
    else {
        //Show maximum number of clusters we're at the minimum level set
        numberOnScreen = _numberOfClusters;
    }
    
    //Can never have more than the available annotations in the pool
    if (numberOnScreen > _numberOfClusters) {
        numberOnScreen = _numberOfClusters;
    }
    
    return numberOnScreen;
}


- (NSSet <NSDictionary <NSString *, NSNumber *> *> *)mapRectsFromMaxNumberOfClusters:(NSUInteger)amount mapRect:(MKMapRect)rect {
    
    if (amount == 0) {
        return [NSSet setWithObject:[NSDictionary dictionaryFromMapRect:rect]];
    }
    
    //Create equal sized rects based on the amount of clusters wanted
    double width = rect.size.width;
    double height = rect.size.height;
    
    float weight = width/height;
    
    int columns = round(sqrt(amount*weight));
    int rows = ceil(amount / (double)columns);
    
    //create basic cluster grid
    double columnWidth = width/columns;
    double rowHeight = height/rows;
    
    
    double x = rect.origin.x;
    double y = rect.origin.y;
    //build array of MKMapRects
    NSMutableSet* set = [[NSMutableSet alloc] initWithCapacity:rows*columns];
    for (int i=0; i< columns; i++) {
        double newX = x + columnWidth*(i);
        for (int j=0; j< rows; j++) {
            double newY = y + rowHeight*(j);
            MKMapRect newRect = MKMapRectMake(newX, newY, columnWidth, rowHeight);
            [set addObject:[NSDictionary dictionaryFromMapRect:newRect]];
        }
    }
    
    return set;
}


#pragma mark - Spread close annotations

- (void)mutateCoordinatesOfClashingAnnotations:(NSSet <ADClusterAnnotation *> *)annotations {
    
    NSDictionary *coordinateValuesToAnnotations = [TSClusterOperation groupLeafAnnotationsByLocationValue:annotations];
    
    for (NSValue *coordinateValue in coordinateValuesToAnnotations.allKeys) {
        NSMutableArray *outletsAtLocation = coordinateValuesToAnnotations[coordinateValue];
        if (outletsAtLocation.count > 1) {
            CLLocationCoordinate2D coordinate;
            [coordinateValue getValue:&coordinate];
            [self repositionAnnotations:outletsAtLocation toAvoidClashAtCoordinate:coordinate];
        }
    }
    
    annotations = [annotations filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ADClusterAnnotation * evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        return evaluatedObject.type == ADClusterAnnotationTypeCluster && evaluatedObject.cluster;
    }]];
    
    for (ADClusterAnnotation *annotation in annotations) {
        for (ADClusterAnnotation *compareAnnotation in annotations) {
            if (compareAnnotation == annotation || [compareAnnotation.cluster.groupID isEqualToString:annotation.cluster.groupID]) {
                continue;
            }
            
            if ([annotation.cluster overlapsClusterOnMap:compareAnnotation.cluster annotationViewMapRectSize:[self mapRectAnnotationViewSize]]) {
                [self repositionAnnotations:@[annotation, compareAnnotation] toAvoidClashAtCoordinate:CLLocationCoordinate2DMidPoint(annotation.cluster.clusterCoordinate, compareAnnotation.cluster.clusterCoordinate)];
            }
        }
    }
}

+ (NSDictionary <NSValue *, NSMutableArray <ADClusterAnnotation *> *>*)groupLeafAnnotationsByLocationValue:(NSSet <ADClusterAnnotation *>*)annotations {
    
    annotations = [annotations filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ADClusterAnnotation * evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        return evaluatedObject.type == ADClusterAnnotationTypeLeaf && evaluatedObject.cluster;
    }]];
    
    return [self groupClusterByLocationValue:annotations];
}

+ (NSDictionary <NSValue *, NSMutableArray <ADClusterAnnotation *> *>*)groupClusterAnnotationsByLocationValue:(NSSet <ADClusterAnnotation *>*)annotations {
    
    annotations = [annotations filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ADClusterAnnotation * evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        return evaluatedObject.type == ADClusterAnnotationTypeCluster && evaluatedObject.cluster;
    }]];
    
    return [self groupClusterByLocationValue:annotations];
}

+ (NSDictionary <NSValue *, NSMutableArray <ADClusterAnnotation *> *>*)groupClusterByLocationValue:(NSSet <ADClusterAnnotation *>*)annotations {
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    for (ADClusterAnnotation *pin in annotations) {
        
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DRoundedLonLat(pin.cluster.clusterCoordinate, 5);
        NSValue *coordinateValue = [NSValue valueWithBytes:&coordinate objCType:@encode(CLLocationCoordinate2D)];
        
        NSMutableArray *annotationsAtLocation = result[coordinateValue];
        if (!annotationsAtLocation) {
            annotationsAtLocation = [NSMutableArray array];
            result[coordinateValue] = annotationsAtLocation;
        }
        
        [annotationsAtLocation addObject:pin];
    }
    
    return result;
}



+ (NSDictionary <NSValue *, NSMutableArray <id<MKAnnotation>> *>*)groupAnnotationsByLocationValue:(NSSet <id<MKAnnotation>>*)annotations {
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    for (id<MKAnnotation> annotation in annotations) {
        
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DRoundedLonLat(annotation.coordinate, 5);
        NSValue *coordinateValue = [NSValue valueWithBytes:&coordinate objCType:@encode(CLLocationCoordinate2D)];
        
        NSMutableArray *annotationsAtLocation = result[coordinateValue];
        if (!annotationsAtLocation) {
            annotationsAtLocation = [NSMutableArray array];
            result[coordinateValue] = annotationsAtLocation;
        }
        
        [annotationsAtLocation addObject:annotation];
    }
    return result;
}

- (void)repositionAnnotations:(NSArray <ADClusterAnnotation *>*)annotations toAvoidClashAtCoordinate:(CLLocationCoordinate2D)coordinate {
    
    if ([_mapView.clusterDelegate respondsToSelector:@selector(mapView:shouldRepositionAnnotations:toAvoidClashAtCoordinate:)]) {
        if (![_mapView.clusterDelegate mapView:_mapView shouldRepositionAnnotations:annotations toAvoidClashAtCoordinate:coordinate]) {
            return;
        }
    }
    
    MKMapRect mapViewRect = _mapView.visibleMapRect;
    
    CLLocationDistance width = MKMetersBetweenMapPoints(mapViewRect.origin, MKMapPointMake(mapViewRect.origin.x + mapViewRect.size.width, mapViewRect.origin.y));
    CLLocationDistance height = MKMetersBetweenMapPoints(mapViewRect.origin, MKMapPointMake(mapViewRect.origin.x, mapViewRect.origin.y + mapViewRect.size.height));
    CLLocationDistance minHeightWidth = MIN(width, height);
    
    
    MKMapRect annotationRect = [self mapRectAnnotationViewSize];
    
    CLLocationDistance distance = minHeightWidth/8;
    
    if (!MKMapRectIsNull(annotationRect)) {
        
        MKMapPoint originPoint = annotationRect.origin;
        MKMapPoint sizePoint = MKMapPointMake(annotationRect.origin.x + annotationRect.size.width, annotationRect.origin.y + annotationRect.size.height);
        distance = MKMetersBetweenMapPoints(originPoint, sizePoint);
    }
    
    CLLocationDistance maxRadius = minHeightWidth - (2 * distance);
    
    double radiansBetweenAnnotations = (M_PI * 2) / annotations.count;
    double radius = (distance * annotations.count)/(2 * M_PI);
    
    radius = MIN(maxRadius, radius);
    
    if (annotations.count == 2 && !CLLocationCoordinate2DIsApproxEqual(annotations.firstObject.cluster.clusterCoordinate, annotations.lastObject.cluster.clusterCoordinate, .00001) ) {
        
        
        for (ADClusterAnnotation *annotation in annotations) {
            double bearing = CLLocationCoordinate2DBearingRadians(coordinate, annotation.cluster.clusterCoordinate);
            CLLocationCoordinate2D newCoordinate = [TSClusterOperation calculateCoordinateFrom:coordinate onBearing:bearing atDistance:radius];
            
            annotation.coordinatePostAnimation = newCoordinate;
        }
        
        return;
    }
    
    int i = 0;
    
    for (ADClusterAnnotation *annotation in annotations) {
        
        double bearing = radiansBetweenAnnotations * i;
        CLLocationCoordinate2D newCoordinate = [TSClusterOperation calculateCoordinateFrom:coordinate onBearing:bearing atDistance:radius];
        
        annotation.coordinatePostAnimation = newCoordinate;
        
        i++;
    }
}

+ (CLLocationCoordinate2D)calculateCoordinateFrom:(CLLocationCoordinate2D)coordinate onBearing:(double)bearingInRadians atDistance:(double)distanceInMetres {
    
    double coordinateLatitudeInRadians = coordinate.latitude * M_PI / 180;
    double coordinateLongitudeInRadians = coordinate.longitude * M_PI / 180;
    
    double distanceComparedToEarth = distanceInMetres / 6378100;
    
    double resultLatitudeInRadians = asin(sin(coordinateLatitudeInRadians) * cos(distanceComparedToEarth) + cos(coordinateLatitudeInRadians) * sin(distanceComparedToEarth) * cos(bearingInRadians));
    double resultLongitudeInRadians = coordinateLongitudeInRadians + atan2(sin(bearingInRadians) * sin(distanceComparedToEarth) * cos(coordinateLatitudeInRadians), cos(distanceComparedToEarth) - sin(coordinateLatitudeInRadians) * sin(resultLatitudeInRadians));
    
    CLLocationCoordinate2D result;
    result.latitude = resultLatitudeInRadians * 180 / M_PI;
    result.longitude = resultLongitudeInRadians * 180 / M_PI;
    return result;
}

@end

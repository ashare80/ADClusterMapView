//
//  ADClusterMapView.m
//  ADClusterMapView
//
//  Created by Patrick Nollet on 30/06/11.
//  Copyright 2011 Applidium. All rights reserved.
//

#import <QuartzCore/CoreAnimation.h>
#import "TSClusterMapView.h"
#import "ADClusterAnnotation.h"
#import "ADMapPointAnnotation.h"
#import "NSDictionary+MKMapRect.h"
#import "CLLocation+Utilities.h"
#import "TSClusterOperation.h"

#define DATA_REFRESH_MAX 1000

static NSString * const kTSClusterAnnotationViewID = @"kTSClusterAnnotationViewID-private";
NSString * const KDTreeClusteringProgress = @"KDTreeClusteringProgress";

@interface TSClusterMapView ()

@property (nonatomic, weak) id <TSClusterMapViewDelegate>  secondaryDelegate;

//Clustering
@property (nonatomic, strong) ADMapCluster *rootMapCluster;

@property (nonatomic, strong) NSMutableSet *clusterableAnnotationsAdded;

@property (nonatomic, assign) MKMapRect previousVisibleMapRectClustered;

@property (nonatomic, strong) NSOperationQueue *clusterOperationQueue;
@property (nonatomic, strong) NSOperationQueue *preClusterOperationQueue;

@property (nonatomic, strong) NSCache *annotationViewCache;

@property (nonatomic, strong) NSOperationQueue *treeOperationQueue;

@property (nonatomic, readonly) NSSet *clusterAnnotations;

@property (strong, nonatomic) NSMutableSet *clusterAnnotationsPool;

@property (strong, nonatomic) UIPanGestureRecognizer *panRecognizer;

@end


@implementation TSClusterMapView


- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self initHelpers];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initHelpers];
    }
    return self;
}

- (void)initHelpers {
    
    [self setDefaults];
    
    _clusterAnnotationsPool = [[NSMutableSet alloc] init];
    
    _preClusterOperationQueue = [[NSOperationQueue alloc] init];
    [_preClusterOperationQueue setMaxConcurrentOperationCount:1];
    [_preClusterOperationQueue setName:@"Pre Clustering Queue"];
    
    _clusterOperationQueue = [[NSOperationQueue alloc] init];
    [_clusterOperationQueue setMaxConcurrentOperationCount:1];
    [_clusterOperationQueue setName:@"Clustering Queue"];
    
    _treeOperationQueue = [[NSOperationQueue alloc] init];
    [_treeOperationQueue setMaxConcurrentOperationCount:1];
    [_treeOperationQueue setName:@"Tree Building Queue"];
    
    _clusterAnimationOptions = [TSClusterAnimationOptions defaultOptions];
    _annotationViewCache = [[NSCache alloc] init];
}

- (void)setMonitorMapPan:(BOOL)monitorMapPan {
    
    _monitorMapPan = monitorMapPan;
    
    if (_panRecognizer) {
        [self removeGestureRecognizer:_panRecognizer];
    }
    
    if (monitorMapPan) {
        _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                 action:@selector(didPanMap:)];
        [_panRecognizer setDelegate:self];
        [self addGestureRecognizer:_panRecognizer];
    }
}

- (void)didMoveToSuperview {
    
    [super didMoveToSuperview];
    
    //No longer relevant to display stop operations
    if (!self.superview) {
        [_clusterOperationQueue cancelAllOperations];
        [_treeOperationQueue cancelAllOperations];
    }
}

- (void)setDefaults {
    
    self.clusterPreferredVisibleCount = 20;
    self.clusterDiscrimination = 0.0;
    self.clusterShouldShowSubtitle = YES;
    self.clusterEdgeBufferSize = ADClusterBufferMedium;
    self.clusterTitle = @"%d elements";
    self.clusterZoomsOnTap = YES;
    self.clusterAppearanceAnimated = YES;
}

- (void)setClusterEdgeBufferSize:(ADClusterBufferSize)clusterEdgeBufferSize {
    
    if (clusterEdgeBufferSize < 0) {
        clusterEdgeBufferSize = 0;
    }
    
    _clusterEdgeBufferSize = clusterEdgeBufferSize;
}

- (void)setClusterPreferredVisibleCount:(NSUInteger)clustersOnScreen {
    
    _clusterPreferredVisibleCount = clustersOnScreen;
    
    [self clusterVisibleMapRectForceRefresh:YES];
}

- (void)setClusterDiscrimination:(float)clusterDiscrimination {
    
    if (clusterDiscrimination > 1) {
        clusterDiscrimination = 1;
    }
    else if (clusterDiscrimination < 0) {
        clusterDiscrimination = 0;
    }
    
    _clusterDiscrimination = clusterDiscrimination;
}

- (NSUInteger)numberOfClusters {
    
    NSUInteger adjusted = _clusterPreferredVisibleCount + (_clusterPreferredVisibleCount*_clusterEdgeBufferSize);
    if (_clusterPreferredVisibleCount > 6) {
        return adjusted;
    }
    return _clusterPreferredVisibleCount;
}

- (void)needsRefresh {
    
    [self createKDTreeAndCluster:_clusterableAnnotationsAdded];
}

#pragma mark - Add/Remove Annotations


- (void)addAnnotation:(id<MKAnnotation>)annotation {
    if (![_clusterableAnnotationsAdded containsObject:annotation]) {
        [super addAnnotation:annotation];
    }
}

- (void)addAnnotations:(NSArray *)annotations {
    
    NSMutableSet *annotationsToAdd = [NSMutableSet setWithArray:annotations];
    [annotationsToAdd minusSet:_clusterableAnnotationsAdded];
    
    if (annotationsToAdd.count) {
        [super addAnnotations:annotationsToAdd.allObjects];
    }
}

- (void)addClusteredAnnotation:(id<MKAnnotation>)annotation {
    
    BOOL refresh = NO;
    
    if (_clusterableAnnotationsAdded.count < DATA_REFRESH_MAX) {
        refresh = YES;
    }
    
    [self addClusteredAnnotation:annotation clusterTreeRefresh:refresh];
}

- (void)addClusteredAnnotation:(id<MKAnnotation>)annotation clusterTreeRefresh:(BOOL)refresh {
    
    if (!annotation || [_clusterableAnnotationsAdded containsObject:annotation]) {
        return;
    }
    
    if (_clusterableAnnotationsAdded) {
        [_clusterableAnnotationsAdded addObject:annotation];
    }
    else {
        _clusterableAnnotationsAdded = [[NSMutableSet alloc] initWithObjects:annotation, nil];
    }
    
    if (refresh || _treeOperationQueue.operationCount > 10) {
        [self needsRefresh];
        return;
    }
    
    
    __weak TSClusterMapView *weakSelf = self;
    [_treeOperationQueue addOperationWithBlock:^{
        //Attempt to insert in existing root cluster - will fail if small data set or an outlier
        [_rootMapCluster mapView:self addAnnotation:[[ADMapPointAnnotation alloc] initWithAnnotation:annotation] completion:^(BOOL added) {
            
            TSClusterMapView *strongSelf = weakSelf;
            
            if (added) {
                [strongSelf clusterVisibleMapRectForceRefresh:YES];
            }
            else {
                [strongSelf needsRefresh];
            }
        }];
    }];
}

- (void)addClusteredAnnotations:(NSArray *)annotations {
    
    if (!annotations || !annotations.count) {
        return;
    }
    
    NSInteger count = _clusterableAnnotationsAdded.count;
    
    if (_clusterableAnnotationsAdded) {
        [_clusterableAnnotationsAdded unionSet:[NSSet setWithArray:annotations]];
    }
    else {
        _clusterableAnnotationsAdded = [[NSMutableSet alloc] initWithArray:annotations];
    }
    
    if (count != _clusterableAnnotationsAdded.count) {
        [self needsRefresh];
    }
}

- (void)removeAnnotation:(id<MKAnnotation>)annotation {
    
    if (!annotation) {
        return;
    }
    
    if ([_clusterableAnnotationsAdded containsObject:annotation]) {
        [_clusterableAnnotationsAdded removeObject:annotation];
        
        //Small data set just rebuild
        if (_clusterableAnnotationsAdded.count < DATA_REFRESH_MAX || _treeOperationQueue.operationCount > 10) {
            [self needsRefresh];
        }
        else {
            
            
            __weak TSClusterMapView *weakSelf = self;
            [_treeOperationQueue addOperationWithBlock:^{
                [weakSelf.rootMapCluster mapView:self removeAnnotation:annotation completion:^(BOOL removed) {
                    
                    TSClusterMapView *strongSelf = weakSelf;
                    
                    if (removed) {
                        [strongSelf clusterVisibleMapRectForceRefresh:YES];
                    }
                    else {
                        [strongSelf needsRefresh];
                    }
                }];
            }];
        }
    }
    
    [super removeAnnotation:annotation];
}

- (void)removeAnnotations:(NSArray *)annotations {
    
    if (!annotations) {
        return;
    }
    
    NSUInteger previousCount = _clusterableAnnotationsAdded.count;
    NSSet *set = [NSSet setWithArray:annotations];
    [_clusterableAnnotationsAdded minusSet:set];
    
    if (_clusterableAnnotationsAdded.count != previousCount) {
        [self needsRefresh];
    }
    
    [super removeAnnotations:annotations];
}

- (void)removeAllAnnotations {
    [super removeAnnotations:_clusterableAnnotationsAdded.allObjects];
    [_clusterableAnnotationsAdded removeAllObjects];
}

#pragma mark - Annotations

- (void)refreshClusterAnnotation:(ADClusterAnnotation *)annotation {
    
    MKAnnotationView *viewToAdd = [self refreshAnnotationViewForAnnotation:annotation];
    MKAnnotationView *viewToCache = [annotation.annotationView updateWithAnnotationView:viewToAdd];
    [self cacheAnnotationView:viewToCache];
}

- (NSArray *)visibleClusterAnnotations {
    NSMutableArray * displayedAnnotations = [[NSMutableArray alloc] init];
    for (ADClusterAnnotation * annotation in [_clusterAnnotationsPool copy]) {
        if (!annotation.offscreen) {
            [displayedAnnotations addObject:annotation];
        }
    }
    
    return displayedAnnotations;
}

- (NSArray *)annotations {
    
    NSMutableSet *set = [NSMutableSet setWithArray:[super annotations]];
    [set minusSet:self.clusterAnnotations];
    [set unionSet:_clusterableAnnotationsAdded];
    
    return set.allObjects;
}

- (NSSet *)clusterAnnotations {
    
    NSMutableSet *mutableSet = [[NSMutableSet alloc] init];
    for (ADClusterAnnotation *annotation in [super annotations]) {
        if ([annotation isKindOfClass:[ADClusterAnnotation class]]) {
            [mutableSet addObject:annotation];
        }
    }
    
    return mutableSet;
}

- (ADClusterAnnotation *)currentClusterAnnotationForAddedAnnotation:(id<MKAnnotation>)annotation {
    
    for (ADClusterAnnotation *clusterAnnotation in self.visibleClusterAnnotations) {
        if ([clusterAnnotation.cluster isRootClusterForAnnotation:annotation]) {
            return clusterAnnotation;
        }
    }
    return nil;
}



#pragma mark - MKAnnotationView Cache

- (MKAnnotationView *)dequeueReusableAnnotationViewWithIdentifier:(NSString *)identifier {
    
    MKAnnotationView *view = [super dequeueReusableAnnotationViewWithIdentifier:identifier];
    
    if (!view) {
        view = [self annotationViewFromCacheWithKey:identifier];
    }
    return view;
}

- (MKAnnotationView *)annotationViewFromCacheWithKey:(NSString *)identifier {
    
    if ([identifier isEqualToString:kTSClusterAnnotationViewID]) {
        return nil;
    }
    
    MKAnnotationView *view;
    NSMutableSet *set = [_annotationViewCache objectForKey:identifier];
    if (set.count) {
        view = [set anyObject];
        [set removeObject:view];
    }
    
    [view prepareForReuse];
    
    return view;
}

- (void)cacheAnnotationView:(MKAnnotationView *)annotationView {
    
    if (!annotationView) {
        return;
    }
    
    annotationView.annotation = nil;
    
    NSString *reuseIdentifier = annotationView.reuseIdentifier;
    if ([reuseIdentifier isEqualToString:kTSClusterAnnotationViewID]) {
        reuseIdentifier = NSStringFromClass([annotationView class]);
    }
    
    NSMutableSet *set = [_annotationViewCache objectForKey:reuseIdentifier];
    if (set) {
        [set addObject:annotationView];
    }
    else {
        set = [[NSMutableSet alloc] initWithCapacity:10];
        [set addObject:annotationView];
        [_annotationViewCache setObject:set forKey:reuseIdentifier];
    }
}


#pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    
    return _monitorMapPan;
}

- (void)didPanMap:(UIGestureRecognizer*)gestureRecognizer {
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
        [self userWillPanMapView:self];
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self userDidPanMapView:self];
    }
}


#pragma mark - Objective-C Runtime and subclassing methods
- (void)setDelegate:(id<TSClusterMapViewDelegate>)delegate {
    /*
     For an undefined reason, setDelegate is called multiple times. The first time, it is called with delegate = nil
     Therefore _secondaryDelegate may be nil when [_secondaryDelegate respondsToSelector:aSelector] is called (result : NO)
     There is some caching done in order to avoid calling respondsToSelector: too much. That's why if we don't take care the runtime will guess that we always have [_secondaryDelegate respondsToSelector:] = NO
     Therefore we clear the cache by setting the delegate to nil.
     */
    [super setDelegate:nil];
    _secondaryDelegate = delegate;
    [super setDelegate:self];
    
    MKAnnotationView *annotationView = [self mapView:self viewForClusterAnnotation:[[ADClusterAnnotation alloc] init]];
    self.clusterAnnotationViewSize = annotationView.frame.size;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL respondsToSelector = [super respondsToSelector:aSelector] || [_secondaryDelegate respondsToSelector:aSelector];
    return respondsToSelector;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([_secondaryDelegate respondsToSelector:[anInvocation selector]]) {
        [anInvocation invokeWithTarget:_secondaryDelegate];
    } else {
        [super forwardInvocation:anInvocation];
    }
}


#pragma mark - Clustering

- (void)createKDTreeAndCluster:(NSSet *)annotations {
    
    if (!annotations) {
        return;
    }
    
    annotations = [annotations copy];
    
    [_treeOperationQueue cancelAllOperations];
    
    __weak TSClusterMapView *weakSelf = self;
    [_treeOperationQueue addOperationWithBlock:^{
        
        // use wrapper annotations that expose a MKMapPoint property instead of a CLLocationCoordinate2D property
        NSMutableSet * mapPointAnnotations = [[NSMutableSet alloc] initWithCapacity:annotations.count];
        for (id<MKAnnotation> annotation in annotations) {
            ADMapPointAnnotation * mapPointAnnotation = [[ADMapPointAnnotation alloc] initWithAnnotation:annotation];
            [mapPointAnnotations addObject:mapPointAnnotation];
        }
        
        [ADMapCluster rootClusterForAnnotations:mapPointAnnotations mapView:self completion:^(ADMapCluster *mapCluster) {
            
            TSClusterMapView *strongSelf = weakSelf;
            
            strongSelf.rootMapCluster = mapCluster;
            
            [strongSelf clusterVisibleMapRectForceRefresh:YES];
        }];
    }];
}


- (void)initAnnotationPools:(NSUInteger)numberOfAnnotationsInPool {
    
    if (!numberOfAnnotationsInPool) {
        return;
    }
    
    //Count for splits
    numberOfAnnotationsInPool*=2;
    
    NSArray *toAdd;
    
    if (!self.clusterAnnotationsPool.count) {
        for (int i = 0; i < numberOfAnnotationsInPool; i++) {
            ADClusterAnnotation * annotation = [[ADClusterAnnotation alloc] init];
            [_clusterAnnotationsPool addObject:annotation];
        }
        
        toAdd = _clusterAnnotationsPool.allObjects;
    }
    else if (numberOfAnnotationsInPool > _clusterAnnotationsPool.count) {
        
        NSUInteger difference = numberOfAnnotationsInPool - _clusterAnnotationsPool.count;
        NSMutableArray *mutableAdd = [[NSMutableArray alloc] initWithCapacity:difference];
        
        for (int i = 0; i < difference; i++) {
            ADClusterAnnotation * annotation = [[ADClusterAnnotation alloc] init];
            [_clusterAnnotationsPool addObject:annotation];
            [mutableAdd addObject:annotation];
        }
        
        toAdd = mutableAdd;
    }
    
    if (toAdd.count) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [super addAnnotations:toAdd];
        }];
    }
}

- (BOOL)shouldNotAnimate {
    return (!self.superview || self.layer.animationKeys);
}

- (void)splitClusterToOriginal:(ADMapCluster *)cluster {
    
    if ([self shouldNotAnimate]) {
        return;
    }
    
    [self initAnnotationPools:[self numberOfClusters]+cluster.clusterCount];
    
    [_clusterOperationQueue cancelAllOperations];
    [_clusterOperationQueue addOperation:[TSClusterOperation mapView:self splitCluster:cluster clusterAnnotationsPool:_clusterAnnotationsPool]];
}

- (void)clusterVisibleMapRectForceRefresh:(BOOL)isNewCluster {
    
    if ([self shouldNotAnimate]) {
        return;
    }
    
    if (isNewCluster) {
        _previousVisibleMapRectClustered = MKMapRectNull;
    }
    
    
    [_preClusterOperationQueue addOperationWithBlock:^{
        
        //Create buffer room for map drag outside visible rect before next regionDidChange
        MKMapRect clusteredMapRect = [self visibleMapRectWithBuffer:_clusterEdgeBufferSize];
        
        if (_clusterEdgeBufferSize) {
            if (!MKMapRectIsNull(_previousVisibleMapRectClustered) &&
                !MKMapRectIsEmpty(_previousVisibleMapRectClustered)) {
                
                //did the map pan far enough or zoom? Compare to rounded size as decimals fluctuate
                MKMapRect halfBufferRect = MKMapRectInset(_previousVisibleMapRectClustered, (_previousVisibleMapRectClustered.size.width - self.visibleMapRect.size.width)/4, (_previousVisibleMapRectClustered.size.height - self.visibleMapRect.size.height)/4);
                if (MKMapRectSizeIsEqual(clusteredMapRect, _previousVisibleMapRectClustered) &&
                    MKMapRectContainsRect(halfBufferRect, self.visibleMapRect)
                    ) {
                    return;
                }
            }
        }
        
        [self initAnnotationPools:[self numberOfClusters]];
        
        [_clusterOperationQueue cancelAllOperations];
        
        [self mapViewWillBeginClusteringAnimation:self];
        
        __weak TSClusterMapView *weakSelf = self;
        TSClusterOperation *operation = [TSClusterOperation mapView:self
                                                               rect:clusteredMapRect
                                                        rootCluster:_rootMapCluster
                                               showNumberOfClusters:[self numberOfClusters]
                                                 clusterAnnotations:self.clusterAnnotationsPool
                                                         completion:^(MKMapRect clusteredRect, BOOL finished, NSSet *poolAnnotationsToRemove) {
                                                             
                                                             TSClusterMapView *strongSelf = weakSelf;
                                                             
                                                             
                                                             if (poolAnnotationsToRemove.count > 0) {
                                                                 [_preClusterOperationQueue addOperationWithBlock:^{
                                                                     [strongSelf poolAnnotationsToRemove:poolAnnotationsToRemove];
                                                                 }];
                                                             }
                                                             
                                                             if (finished) {
                                                                 strongSelf.previousVisibleMapRectClustered = clusteredRect;
                                                                 
                                                                 [strongSelf mapViewDidFinishClusteringAnimation:strongSelf];
                                                             }
                                                             else {
                                                                 [strongSelf mapViewDidCancelClusteringAnimation:strongSelf];
                                                             }
                                                         }];
        [_clusterOperationQueue addOperation:operation];
        [_clusterOperationQueue setSuspended:NO];
    }];
}

- (void)poolAnnotationsToRemove:(NSSet *)remove {
    
    if (!remove.count) {
        return;
    }
    
    NSArray *allObjects = remove.allObjects;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [super removeAnnotations:allObjects];
    }];
    
    [_clusterAnnotationsPool minusSet:remove];
}

- (MKMapRect)visibleMapRectWithBuffer:(ADClusterBufferSize)bufferSize; {
    
    if (!bufferSize) {
        return self.visibleMapRect;
    }
    
    double width = self.visibleMapRect.size.width;
    double height = self.visibleMapRect.size.height;
    
    //Up Down Left Right - UpLeft UpRight DownLeft DownRight
    NSUInteger directions = 8;
    //Large (8) = One full screen size in all directions
    
    MKMapRect mapRect = self.visibleMapRect;
    mapRect = MKMapRectUnion(mapRect, MKMapRectOffset(self.visibleMapRect, -width*bufferSize/directions, -height*bufferSize/directions));
    mapRect = MKMapRectUnion(mapRect, MKMapRectOffset(self.visibleMapRect, width*bufferSize/directions, height*bufferSize/directions));
    
    return mapRect;
}



#pragma mark - MKMapViewDelegate


- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:regionWillChangeAnimated:)]) {
        [_secondaryDelegate mapView:self regionWillChangeAnimated:animated];
    }
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    
    [self clusterVisibleMapRectForceRefresh:NO];
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:regionDidChangeAnimated:)]) {
        [_secondaryDelegate mapView:self regionDidChangeAnimated:animated];
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    
    BOOL isClusterAnnotation = NO;
    ADClusterAnnotation *clusterAnnotation;
    if ([view isKindOfClass:[TSClusterAnnotationView class]]) {
        clusterAnnotation = view.annotation;
        isClusterAnnotation = clusterAnnotation.type == ADClusterAnnotationTypeCluster;
    }
    
    if (_clusterZoomsOnTap && isClusterAnnotation){
        [self deselectAnnotation:view.annotation animated:NO];
    }
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:didSelectAnnotationView:)]) {
        [_secondaryDelegate mapView:mapView didSelectAnnotationView:[self filterInternalView:view]];
    }
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:didDeselectAnnotationView:)]) {
        [_secondaryDelegate mapView:mapView didDeselectAnnotationView:[self filterInternalView:view]];
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:annotationView:calloutAccessoryControlTapped:)]) {
        [_secondaryDelegate mapView:mapView annotationView:[self filterInternalView:view] calloutAccessoryControlTapped:control];
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:annotationView:didChangeDragState:fromOldState:)]) {
        [_secondaryDelegate mapView:mapView annotationView:[self filterInternalView:view] didChangeDragState:newState fromOldState:oldState];
    }
}

- (void)selectAnnotation:(id<MKAnnotation>)annotation animated:(BOOL)animated {
    
    if ([_clusterableAnnotationsAdded containsObject:annotation]) {
        for (ADClusterAnnotation *clusterAnnotation in self.visibleClusterAnnotations) {
            if ([clusterAnnotation.originalAnnotations containsObject:annotation]) {
                [super selectAnnotation:clusterAnnotation animated:animated];
                return;
            }
        }
        return;
    }
    
    [super selectAnnotation:annotation animated:animated];
}

- (MKAnnotationView *)filterInternalView:(MKAnnotationView *)view {
    
    if ([view isKindOfClass:[TSClusterAnnotationView class]]) {
        if (((TSClusterAnnotationView *)view).addedView) {
            return ((TSClusterAnnotationView *)view).addedView;
        }
    }
    
    return view;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if (![annotation isKindOfClass:[ADClusterAnnotation class]]) {
        if ([_secondaryDelegate respondsToSelector:@selector(mapView:viewForAnnotation:)]) {
            return [_secondaryDelegate mapView:self viewForAnnotation:annotation];
        }
        return nil;
    }
    
    TSClusterAnnotationView *view;
    MKAnnotationView *delegateAnnotationView = [self refreshAnnotationViewForAnnotation:annotation];
    if (delegateAnnotationView) {
        view = (TSClusterAnnotationView *)[self dequeueReusableAnnotationViewWithIdentifier:NSStringFromClass([TSClusterAnnotationView class])];
        [self cacheAnnotationView:[view updateWithAnnotationView:delegateAnnotationView]];
        
        if (!view) {
            view = [[TSClusterAnnotationView alloc] initWithAnnotation:annotation
                                                       reuseIdentifier:NSStringFromClass([TSClusterAnnotationView class])
                                              containingAnnotationView:delegateAnnotationView];
        }
    }
    
    return view;
}

- (MKAnnotationView *)refreshAnnotationViewForAnnotation:(id<MKAnnotation>)annotation  {
    
    MKAnnotationView *delegateAnnotationView;
    
    // only leaf clusters have annotations
    if (((ADClusterAnnotation *)annotation).type == ADClusterAnnotationTypeLeaf) {
        annotation = [((ADClusterAnnotation *)annotation).originalAnnotations firstObject];
        if ([_secondaryDelegate respondsToSelector:@selector(mapView:viewForAnnotation:)]) {
            delegateAnnotationView = [_secondaryDelegate mapView:self viewForAnnotation:annotation];
        }
    }
    else if (![_secondaryDelegate respondsToSelector:@selector(mapView:viewForClusterAnnotation:)]) {
        if ([_secondaryDelegate respondsToSelector:@selector(mapView:viewForAnnotation:)]) {
            delegateAnnotationView = [_secondaryDelegate mapView:self viewForAnnotation:annotation];
        }
    }
    else {
        delegateAnnotationView = [self mapView:self viewForClusterAnnotation:annotation];
    }
    
    //If dequeued it won't have an annotation set;
    if (!delegateAnnotationView.annotation) {
        delegateAnnotationView.annotation = annotation;
    }
    
    return delegateAnnotationView;
}

#pragma mark - Touch Event

//Annotation selection is a touch down event. This will simulate a touch up inside selection of annotation for zoomOnTap
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    
    if (_clusterZoomsOnTap){
        for (UITouch *touch in touches) {
            
            TSClusterAnnotationView *view = [self clusterAnnotationForSubview:touch.view];
            
            if (view) {
                ADClusterAnnotation *clusterAnnotation = view.annotation;
                BOOL isClusterAnnotation = clusterAnnotation.type == ADClusterAnnotationTypeCluster;
                
                //Mapview seems to have a limit on set visible map rect let's manually split if we can't zoom anymore
                if (isClusterAnnotation) {
                    if(self.camera.altitude < 500) {
                        [self deselectAnnotation:view.annotation animated:NO];
                        [self splitClusterToOriginal:clusterAnnotation.cluster];
                        return;
                    }
                    [self deselectAnnotation:view.annotation animated:NO];
                    
                    MKMapRect zoomTo = ((ADClusterAnnotation *)view.annotation).cluster.mapRect;
                    zoomTo = [self mapRectThatFits:zoomTo edgePadding:UIEdgeInsetsMake(view.frame.size.height, view.frame.size.width, view.frame.size.height, view.frame.size.width)];
                    
                    if (MKMapRectSizeIsGreaterThanOrEqual(zoomTo, self.visibleMapRect)) {
                        zoomTo = MKMapRectInset(zoomTo, zoomTo.size.width/4, zoomTo.size.width/4);
                    }
                    
                    MKCoordinateRegion region = MKCoordinateRegionForMapRect(zoomTo);
                    
                    if (zoomTo.size.width < 3000) {
                        
                        float ratio = self.camera.altitude/self.visibleMapRect.size.width;
                        
                        float altitude = ratio*zoomTo.size.width;
                        if (altitude < 280) {
                            altitude = 280;
                        }
                        
                        MKMapCamera *camera = [self.camera copy];
                        camera.altitude = altitude;
                        camera.centerCoordinate = region.center;
                        [self setCamera:camera animated:YES];
                    }
                    else {
                        [self setRegion:region animated:YES];
                    }
                }
            }
        }
    }
}

- (TSClusterAnnotationView *)clusterAnnotationForSubview:(UIView *)view {
    
    if (!view) {
        return nil;
    }
    
    if ([view isKindOfClass:[TSClusterAnnotationView class]]) {
        return (TSClusterAnnotationView *)view;
    }
    
    return [self clusterAnnotationForSubview:view.superview];
}

#pragma mark - ADClusterMapView Delegate

- (MKAnnotationView *)mapView:(TSClusterMapView *)mapView viewForClusterAnnotation:(id <MKAnnotation>)annotation {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:viewForClusterAnnotation:)]) {
        return [_secondaryDelegate mapView:self viewForClusterAnnotation:annotation];
    }
    
    return nil;
}

- (void)mapView:(TSClusterMapView *)mapView willBeginBuildingClusterTreeForMapPoints:(NSSet *)annotations {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:willBeginBuildingClusterTreeForMapPoints:)]) {
        [_secondaryDelegate mapView:mapView willBeginBuildingClusterTreeForMapPoints:annotations];
    }
}

- (void)mapView:(TSClusterMapView *)mapView didFinishBuildingClusterTreeForMapPoints:(NSSet *)annotations {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapView:didFinishBuildingClusterTreeForMapPoints:)]) {
        [_secondaryDelegate mapView:mapView didFinishBuildingClusterTreeForMapPoints:annotations];
    }
}

- (void)mapViewWillBeginClusteringAnimation:(TSClusterMapView *)mapView{
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapViewWillBeginClusteringAnimation:)]) {
        [_secondaryDelegate mapViewWillBeginClusteringAnimation:mapView];
    }
}

- (void)mapViewDidCancelClusteringAnimation:(TSClusterMapView *)mapView {
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapViewDidCancelClusteringAnimation:)]) {
        [_secondaryDelegate mapViewDidCancelClusteringAnimation:mapView];
    }
}

- (void)mapViewDidFinishClusteringAnimation:(TSClusterMapView *)mapView{
    
    if ([_secondaryDelegate respondsToSelector:@selector(mapViewDidFinishClusteringAnimation:)]) {
        [_secondaryDelegate mapViewDidFinishClusteringAnimation:mapView];
    }
}

- (void)userWillPanMapView:(TSClusterMapView *)mapView {
    
    if ([_secondaryDelegate respondsToSelector:@selector(userWillPanMapView:)]) {
        [_secondaryDelegate userWillPanMapView:mapView];
    }
}

- (void)userDidPanMapView:(TSClusterMapView *)mapView {
    
    if ([_secondaryDelegate respondsToSelector:@selector(userDidPanMapView:)]) {
        [_secondaryDelegate userDidPanMapView:mapView];
    }
}

@end

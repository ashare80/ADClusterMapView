//
//  TSClusterMapViewTests.m
//  TSClusterMapViewTests
//
//  Created by Adam Share on 01/20/2015.
//  Copyright (c) 2014 Adam Share. All rights reserved.
//

#import "TSStreetLightAnnotation.h"
#import <TSClusterMapView/TSClusterMapView.h>

@interface TSClusterMapView (Tree)

- (void)createKDTreeAndCluster:(NSSet <id<MKAnnotation>> *)annotations completion:(KdtreeCompletionBlock)completion;

@end

SpecBegin(InitialSpecs)

describe(@"KD Tree Build", ^{
    
    TSClusterMapView *mapView = [[TSClusterMapView alloc] initWithFrame:CGRectMake(0, 0, 200, 500)];
    
//    it(@"", ^{
//    });
    
    it(@"Cluster street lights", ^AsyncBlock {
        
        [[NSOperationQueue new] addOperationWithBlock:^{
            NSData * JSONData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"CDStreetlights" ofType:@"json"]];
            
            NSMutableSet *mutableSet = [[NSMutableSet alloc] init];
            for (NSDictionary * annotationDictionary in [NSJSONSerialization JSONObjectWithData:JSONData options:kNilOptions error:NULL]) {
                TSStreetLightAnnotation * annotation = [[TSStreetLightAnnotation alloc] initWithDictionary:annotationDictionary];
                [mutableSet addObject:annotation];
            }
            
            [mapView createKDTreeAndCluster:mutableSet completion:^(ADMapCluster *mapCluster) {
                if (mapCluster) {
                    done();
                }
            }];
        }];
    });
});

SpecEnd

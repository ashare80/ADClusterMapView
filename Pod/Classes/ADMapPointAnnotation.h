//
//  ADMapPointAnnotation.h
//  ClusterDemo
//
//  Created by Patrick Nollet on 11/10/12.
//  Copyright (c) 2012 Applidium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

/**
 * Do not subclass. This is a wrapper to give annotations added to cluster a map point.
 */
@interface ADMapPointAnnotation : NSObject <NSCopying>

@property (nonatomic, readonly) MKMapPoint mapPoint;

@property (nonatomic, readonly) id<MKAnnotation> annotation;

- (id)initWithAnnotation:(id<MKAnnotation>)annotation;

@end

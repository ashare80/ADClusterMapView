//
//  ADMapPointAnnotation.m
//  ClusterDemo
//
//  Created by Patrick Nollet on 11/10/12.
//  Copyright (c) 2012 Applidium. All rights reserved.
//

#import "ADMapPointAnnotation.h"

@implementation ADMapPointAnnotation

- (id)initWithAnnotation:(id<MKAnnotation>)annotation {
    self = [super init];
    if (self) {
        _mapPoint = MKMapPointForCoordinate(annotation.coordinate);
        _annotation = annotation;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    
    return [[[self class] alloc] initWithAnnotation:_annotation];
}

- (BOOL)isEqual:(ADMapPointAnnotation *)other
{
    if (other == self) {
        return YES;
    } else {
        if ([other isKindOfClass:[self class]]) {
            return [self.annotation isEqual:other.annotation];
        }
        return NO;
    }
}

- (NSUInteger)hash
{
    return [@(self.mapPoint.x) hash] ^ [@(self.mapPoint.y) hash] ^ [self.annotation hash];
}

@end

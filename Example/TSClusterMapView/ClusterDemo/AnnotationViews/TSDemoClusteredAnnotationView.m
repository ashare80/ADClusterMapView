//
//  TSDemoClusteredAnnotationView.m
//  ClusterDemo
//
//  Created by Adam Share on 1/13/15.
//  Copyright (c) 2015 Applidium. All rights reserved.
//

#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#import "TSDemoClusteredAnnotationView.h"
#import "CDMapViewController.h"

@implementation TSDemoClusteredAnnotationView

- (id)initWithAnnotation:(ADClusterAnnotation *)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        
        self.label = [[UILabel alloc] initWithFrame:self.frame];
        
        if ([annotation.cluster.treeID isEqualToString:CDStreetLightJsonFile]) {
            self.image = [UIImage imageNamed:@"ClusterAnnotationYellow"];
            self.label.textColor = UIColorFromRGB(0xf6d262);
        }
        else if ([annotation.cluster.treeID isEqualToString:CDToiletJsonFile]) {
            self.image = [UIImage imageNamed:@"ClusterAnnotationGreen"];
            self.label.textColor = UIColorFromRGB(0x6fc99d);
        }
        else {
            self.image = [UIImage imageNamed:@"ClusterAnnotation"];
            self.label.textColor = UIColorFromRGB(0x009fd6);
        }
        
        self.frame = CGRectMake(0, 0, self.image.size.width, self.image.size.height);
        self.label.frame = self.frame;
        self.label.textAlignment = NSTextAlignmentCenter;
        self.label.font = [UIFont systemFontOfSize:10];
        self.label.center = CGPointMake(self.image.size.width/2, self.image.size.height*.43);
        self.centerOffset = CGPointMake(0, -self.frame.size.height/2);
        
        [self addSubview:self.label];
        
        self.canShowCallout = YES;
        
        [self clusteringAnimation];
    }
    return self;
}

- (void)clusteringAnimation {
    
    ADClusterAnnotation *clusterAnnotation = (ADClusterAnnotation *)self.annotation;
    
    NSUInteger count = clusterAnnotation.clusterCount;
    self.label.text = [self numberLabelText:count];
    
    if ([clusterAnnotation.cluster.treeID isEqualToString:CDStreetLightJsonFile]) {
        self.image = [UIImage imageNamed:@"ClusterAnnotationYellow"];
        self.label.textColor = UIColorFromRGB(0xf6d262);
    }
    else if ([clusterAnnotation.cluster.treeID isEqualToString:CDToiletJsonFile]) {
        self.image = [UIImage imageNamed:@"ClusterAnnotationGreen"];
        self.label.textColor = UIColorFromRGB(0x6fc99d);
    }
    else {
        self.image = [UIImage imageNamed:@"ClusterAnnotation"];
        self.label.textColor = UIColorFromRGB(0x009fd6);
    }
}

- (NSString *)numberLabelText:(float)count {
    
    if (!count) {
        return nil;
    }
    
    if (count > 1000) {
        float rounded;
        if (count < 10000) {
            rounded = ceilf(count/100)/10;
            return [NSString stringWithFormat:@"%.1fk", rounded];
        }
        else {
            rounded = roundf(count/1000);
            return [NSString stringWithFormat:@"%luk", (unsigned long)rounded];
        }
    }
    
    return [NSString stringWithFormat:@"%lu", (unsigned long)count];
}


@end

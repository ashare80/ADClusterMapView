//
//  TSBaseAnnotationView.m
//  TapShield
//
//  Created by Adam Share on 4/2/14.
//  Copyright (c) 2014 TapShield, LLC. All rights reserved.
//

#import "TSRefreshedAnnotationView.h"

@implementation TSRefreshedAnnotationView

- (id)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        
    }
    return self;
    
}


- (void)clusteringAnimation {
    
    //Subclass and add your cluster view updates to be animated here
    
    if ([NSOperationQueue mainQueue] != [NSOperationQueue currentQueue]) {
        NSLog(@"NotMain");
    }
}


@end

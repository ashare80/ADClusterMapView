//
//  CLLocation+Equal.m
//  TapShield
//
//  Created by Adam Share on 7/13/14.
//  Copyright (c) 2014 TapShield, LLC. All rights reserved.
//

#import "CLLocation+Utilities.h"

@implementation CLLocation (Utilities)

BOOL CLLocationCoordinate2DIsApproxEqual(CLLocationCoordinate2D coord1, CLLocationCoordinate2D coord2, float epsilon) {
    return (fabs(coord1.latitude - coord2.latitude) < epsilon &&
            fabs(coord1.longitude - coord2.longitude) < epsilon);
}

double CLLocationCoordinate2DBearingRadians(CLLocationCoordinate2D coord1, CLLocationCoordinate2D coord2) {
    
    double lat1 = coord1.latitude;
    double lon1 = coord1.longitude;
    
    double lat2 = coord2.latitude;
    double lon2 = coord2.longitude;
    
    double y = sin(lon2-lon1)*cos(lat2);  //SIN(lon2-lon1)*COS(lat2)
    double x = cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1);
    double bearing = atan2(y, x);
    
    return bearing;
}

CLLocationCoordinate2D CLLocationCoordinate2DMidPoint(CLLocationCoordinate2D coord1, CLLocationCoordinate2D coord2) {
    
    CLLocationCoordinate2D midPoint;
    
    double lon1 = coord1.longitude * M_PI / 180;
    double lon2 = coord2.longitude * M_PI / 180;
    
    double lat1 = coord1.latitude * M_PI / 180;
    double lat2 = coord2.latitude * M_PI / 180;
    
    double dLon = lon2 - lon1;
    
    double x = cos(lat2) * cos(dLon);
    double y = cos(lat2) * sin(dLon);
    
    double lat3 = atan2( sin(lat1) + sin(lat2), sqrt((cos(lat1) + x) * (cos(lat1) + x) + y * y) );
    double lon3 = lon1 + atan2(y, cos(lat1) + x);
    
    midPoint.latitude  = lat3 * 180 / M_PI;
    midPoint.longitude = lon3 * 180 / M_PI;
    
    return midPoint;
}

CLLocationCoordinate2D CLLocationCoordinate2DOffset(CLLocationCoordinate2D coord, double x, double y) {
    return CLLocationCoordinate2DMake(coord.latitude + y, coord.longitude + x);
}

float roundToN(float num, int decimals)
{
    int tenpow = 1;
    for (; decimals; tenpow *= 10, decimals--);
    return round(tenpow * num) / tenpow;
}

CLLocationCoordinate2D CLLocationCoordinate2DRoundedLonLat(CLLocationCoordinate2D coord, int decimalPlace) {
    double lat = roundToN(coord.latitude, decimalPlace);
    double lon = roundToN(coord.longitude, decimalPlace);
    return CLLocationCoordinate2DMake(lat, lon);
}

BOOL MKMapRectSizeIsEqual(MKMapRect rect1, MKMapRect rect2) {
    
    return (round(rect1.size.height) == round(rect2.size.height) &&
            round(rect1.size.width) == round(rect2.size.width));
}

BOOL MKMapRectApproxEqual(MKMapRect rect1, MKMapRect rect2) {
    
    return (round(rect1.size.height) == round(rect2.size.height) &&
            round(rect1.size.width) == round(rect2.size.width) &&
            round(rect1.origin.x) == round(rect2.origin.x) &&
            round(rect1.origin.y) == round(rect2.origin.y));
}

BOOL MKMapRectSizeIsGreaterThanOrEqual(MKMapRect rect1, MKMapRect rect2) {
    
    return (round(rect1.size.height) >= round(rect2.size.height) &&
            round(rect1.size.width) >= round(rect2.size.width));
}


@end

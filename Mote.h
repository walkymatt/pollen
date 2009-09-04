//
//  Mote.h
//  pollen
//
//  Created by Matthew Caldwell on 23/07/2001.
//  Copyright (c) 2001-2009. All rights reserved.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

typedef struct
{
    float x;
    float y;
}
Point2f, Vector2f;

typedef struct
{
    float r;
    float g;
    float b;
}
Color3f, Colour3f;

typedef struct
{
    float x1;
    float y1;
    float x2;
    float y2;
}
Matrix2f;

typedef struct
{
    Point2f	position;
    Point2f	previous;
    Vector2f	velocity;
    float	mass;
    Point2f	home;
    Colour3f	colour;
}
Mote;

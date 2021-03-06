//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Mar 30 2018 09:30:25).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <IDEKit/NSObject-Protocol.h>

@class IDEIssue, NSArray, NSString;
@protocol IDENoteAnnotationExplorableItem;

@protocol IDENoteAnnotationExplorableItem <NSObject>
@property(readonly) IDEIssue *exploredIssue;
@property(readonly, getter=isValid) BOOL valid;
@property(readonly) NSString *title;
@property(readonly) NSArray *locations;
@property(readonly) BOOL isNoteSeverity;
@property(readonly) NSArray *childExplorableItems;
@property(readonly) id <IDENoteAnnotationExplorableItem> parentExplorableItem;
@end


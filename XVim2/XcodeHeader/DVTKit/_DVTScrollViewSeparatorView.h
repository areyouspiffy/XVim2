//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Mar 30 2018 09:30:25).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <AppKit/NSView.h>

@class DVTBorderView, NSVisualEffectView;

@interface _DVTScrollViewSeparatorView : NSView
{
    DVTBorderView *_dividerLine;
    NSVisualEffectView *_vibrancyBlockingVisualEffectView;
}

- (void).cxx_destruct;
- (BOOL)allowsVibrancy;
- (void)updateLayer;
- (BOOL)wantsUpdateLayer;
- (id)initWithFrame:(struct CGRect)arg1;

@end


//
//  LEOOpenTokService.h
//  Leonardo
//
//  Created by Gilles Dezeustre on 3/19/14.
//  Copyright (c) 2014 Leonardo Software. All rights reserved.
//

#define USES_OPENTOK_HIGH_LEVEL_API 1

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTokObjC.h>

#if USES_OPENTOK_HIGH_LEVEL_API
#import <OpenTok/OTPublisher.h>
#import <OpenTok/OTSubscriber.h>
#else
#import "TBExampleSubscriber.h"
#import "TBExamplePublisher.h"
#endif

@protocol LEOOpenTokServiceDelegate <NSObject>
@optional
- (void)sessionDidConnect;
- (void)sessionDidDisconnect;
- (void)sessionDidPublish;
- (void)sessionDidUnpublish;
- (void)sessionDidSubscribe;
- (void)sessionDidUnsubscribe;
- (void)callDidHangUp;
- (void)sessionStreamWasDestroyed;
- (void)sessionConnectionDidFailWithError:(OTError*)error;
- (void)sessionPublishingDidFailWithError:(OTError*)error;
- (void)sessionSubscribingDidFailWithError:(OTError*)error;
@end

@interface LEOOpenTokService : NSObject

@property (strong, nonatomic) NSString *appId;
@property (strong, nonatomic) NSString *sessionId;
@property (strong, nonatomic) NSString *token;
@property BOOL subscribeToSelf;
@property (strong, nonatomic) OTSession *session;
#if USES_OPENTOK_HIGH_LEVEL_API
@property (strong, nonatomic) OTPublisher *publisher;
@property (strong, nonatomic) OTSubscriber* subscriber;
#else
@property (strong, nonatomic) TBExamplePublisher *publisher;
@property (strong, nonatomic) TBExampleSubscriber* subscriber;
#endif
@property (weak, nonatomic) id<LEOOpenTokServiceDelegate> delegate;

+ (instancetype)sharedInstance;

// Connection, publishing and subscribing will be automatic when simply calling
// creation session.
- (BOOL)createSession;

// Call when a video chat session has ended
- (BOOL)destroySession;

// Use the connection functions for special cases like hanging up, recovering attempts and
// debugging.
- (void)manualConnect;
- (void)manualDisconnect;
- (void)manualPublish;
- (void)manualUnpublish;
- (void)manualSubscribe;
- (void)manualUnsubscribe;
- (void)manualResetSession;
- (void)hangUp;

@end

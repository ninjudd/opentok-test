//
//  LEOOpenTokService.m
//  Leonardo
//
//  Created by Gilles Dezeustre on 3/19/14.
//  Copyright (c) 2014 Leonardo Software. All rights reserved.
//

#import "LEOOpenTokService.h"
#import <OpenTok/OpenTokObjC.h>

#if 0
@interface OpenTokObjC : NSObject
// Unpublished opentok logging API
+ (void)setLogBlockQueue:(dispatch_queue_t)queue;
+ (void)setLogBlock:(void (^)(NSString* message, void* arg))logBlock;
@end
#endif

@interface LEOOpenTokService ()<OTPublisherKitDelegate, OTSubscriberKitDelegate, OTSessionDelegate>

@property BOOL autoConnect;
@property BOOL autoPublish;
@property (copy) void(^disconnectCompletion)(BOOL success);
@property (copy) void(^unpublishCompletion)(BOOL success);
@property (copy) void(^unsubscribeCompletion)(BOOL success);

@end

@implementation LEOOpenTokService

#pragma mark
#pragma mark public methods

+ (instancetype)sharedInstance {
  static LEOOpenTokService *sharedLEOOpenTokService = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedLEOOpenTokService = [[LEOOpenTokService alloc] init];

    // Only turn either of these off when debugging.
    sharedLEOOpenTokService.autoConnect = YES;
    sharedLEOOpenTokService.autoPublish = YES;
    
    // Only turn this off when testing the service on one device.
    sharedLEOOpenTokService.subscribeToSelf = NO;
//    
//    [OpenTokObjC setLogBlock:^(NSString* message, void* arg) {;}];
//    [OpenTokObjC setLogBlockQueue:dispatch_get_main_queue()];
  });
  
  return sharedLEOOpenTokService;
}

- (BOOL)createSession {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  NSAssert(_session == nil, @"createSession: self.session != nil");
  
  // Not working with 2.2beta1
  //  set_ot_log_level(5);
  
  _session = [[OTSession alloc] initWithApiKey:self.appId
                                     sessionId:self.sessionId
                                      delegate:self];
  
  if (self.session) {
    NSLog(@"%s Created Session [%@].",__PRETTY_FUNCTION__,self.session.sessionId);
    
    // if autoconnect is true, try to connect as soon as we get connection
    // credentials from openTok
    if (self.autoConnect) {
      [self doConnect:@"createSession"];
    }
    
    return YES;
  } else {
    // Session creation failed, not much we can do in that case.
    // TODO: alert user not session object can be instanced.
    NSLog(@"%s Error: OTSession object could not be created using sessionId and token.",__PRETTY_FUNCTION__);
    
    return NO;
  }
}

- (BOOL)destroySession {
  NSLog(@"%s", __PRETTY_FUNCTION__);

  self.session = nil;
  
  return YES;
}

- (void)manualConnect {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self doConnect:@"manualConnect"];
}

- (void)manualDisconnect {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self doDisconnectWithCompletion:nil :@"manualDisconnect"];
}

- (void)manualPublish {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self doPublish:@"manualPublish"];
}

- (void)manualUnpublish {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self doUnpublishWithCompletion:nil :@"manualUnpublish"];
}

- (void)manualSubscribe {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self subscribeToFirstValidStreamFound:@"manualSubscribe"];
}

- (void)manualUnsubscribe {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self doUnsubscribeWithCompletion:nil :@"manualUnsubscribe"];
}

- (void)manualResetSession {
  [self doDisconnectWithCompletion:^(BOOL success) {
    [self destroySession];
    [self createSession];
  }:@"manualResetSession"];
}

- (void)hangUp {
  [self doDisconnectWithCompletion:^(BOOL success) {
    if (self.delegate && [self.delegate respondsToSelector:@selector(callDidHangUp)]) {
      [self.delegate callDidHangUp];
    }

  } :@"hangUp"];
}

#pragma mark private methods

- (void)resetConnectionObjects:(NSString *)message {
  
  NSLog(@"%s:%@",__PRETTY_FUNCTION__, message);
  
  // Initialize these in case they are not nil and dangling from a previous connection.
  // FIXME: catch the case when that happens and when not properly cleaned up when
  // tearning down the connection.
  self.publisher = nil;
  self.subscriber = nil;
  
  // Do not nil completion blocks since we might call this function in a completion
  // block..., which would result in the block not being called on completion.
}

- (void)doConnect:(NSString *)message {
  
  NSLog(@"%s:%@",__PRETTY_FUNCTION__, message);
  
  [self resetConnectionObjects:[NSString stringWithFormat:@"%@ -> doConnect", message]];
  
  NSAssert(_session, @" _session object has to be instanced");
  
  NSLog(@"%s: connecting Session.", __PRETTY_FUNCTION__);

  OTError *error;
  [_session connectWithToken:self.token error:&error];

  if (error) {
    NSLog(@"%s connectWithToken error: %@", __PRETTY_FUNCTION__, error);
  }
}

- (void)doDisconnectWithCompletion:(void (^)(BOOL))completion :(NSString *)message {
  NSLog(@"%s %@", __PRETTY_FUNCTION__, message);
  
  // Do not force sequential execution of unpublish, unsubscribe before disconnect,
  // it seems to actually mess up the disconnection. Simply disconnect and reset
  // all connected objects on DidDisconnect
  
  if (_session && _session.sessionConnectionStatus == OTSessionConnectionStatusConnected) {
    self.disconnectCompletion = completion;
    
    OTError *error;
    [self.session disconnect:&error];
    if (error) {
      NSLog(@"%s disconnect error: %@", __PRETTY_FUNCTION__, error);
    }

  } else {
    // The session is not connected. All we need to do is runnung the completion block.
    if (completion)
      completion(NO);
    
    // Run didDisconnect delegate callback anyway, for convenience at this point.
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidDisconnect)]) {
      [self.delegate sessionDidDisconnect];
    }
    
  }
}

- (void)doPublish:(NSString *)message {
  NSLog(@"%s %@", __PRETTY_FUNCTION__, message);

  NSString *compoundedMessage = [NSString stringWithFormat:@"%@ -> doPublish", message];
  
  // There is already a publisher, unpublish it.
  [self doUnpublishWithCompletion:^(BOOL success) {
#if USES_OPENTOK_HIGH_LEVEL_API
    _publisher = [[OTPublisher alloc] initWithDelegate:self];
#else
    _publisher = [[TBExamplePublisher alloc] initWithDelegate:self];
    [_publisher setName:[[UIDevice currentDevice] name]];
#endif
    
    OTError *error;
    [_session publish:_publisher error:&error];
    if (error) {
      NSLog(@"%s publish error: %@", __PRETTY_FUNCTION__, error);
    } else {

      _publisher.publishAudio = NO;
      _publisher.publishVideo = YES;
      NSLog(@"%s Publishing [%@].", __PRETTY_FUNCTION__,_publisher.name);
      
      dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidPublish)]) {
          [self.delegate sessionDidPublish];
        }
      });
    }
  } : compoundedMessage];
}

- (void)doUnpublishWithCompletion:(void (^)(BOOL))completion :(NSString *)message {
  NSLog(@"%s %@", __PRETTY_FUNCTION__, message);
  
  if (_publisher) {
    NSLog(@"%s Unpublishing [%@].", __PRETTY_FUNCTION__, _publisher.name?_publisher.name:@"_publisher.name = nil");
    
    // unpublish will remove the publisher view. Will it?
    [_publisher.view removeFromSuperview];
    self.unpublishCompletion = completion;
    OTError *error;
    [_session unpublish:_publisher error:&error];
    if (error) {
      NSLog(@"%s unpublish error: %@", __PRETTY_FUNCTION__, error);
    }
    
  } else {
    // call completion block with NO argument since the publisher was not actually unpublished.
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(NO);
    });
  }
}

- (void)doUnsubscribeWithCompletion:(void (^)(BOOL))completion : (NSString *)message {
  NSLog(@"%s %@", __PRETTY_FUNCTION__, message);
  
  if (_subscriber) {
    NSLog(@"%s Closing Subscriber for [Stream: %@].", __PRETTY_FUNCTION__, _subscriber.stream);
    
    // Do NOT assert on whether we were subscribed to the current session, as the
    // other party may call us on a new session and we need to unsubscribe to the previous one...
    //    assert(_subscriber.session == _session);
    
    // closing the subscriber will remove the publisher view. Will it?
    [_subscriber.view removeFromSuperview];
    
    OTError *error;
    [self.session unsubscribe:_subscriber error:&error];
    if (error) {
      NSLog(@"%s unsubscribe error: %@", __PRETTY_FUNCTION__, error);
      // Closing a subscriber is hopefully a blocking immediate action, because I don't
      // get any notification of its completion afaik.
      if (completion)
        completion(NO);
    } else {
      // Closing a publisher is hopefully a blocking immediate action, because I don't
      // get any notification of its completion afaik.
      if (completion)
        completion(YES);
      
      dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidUnsubscribe)]) {
          [self.delegate sessionDidUnsubscribe];
        }
      });
    }
    _subscriber = nil;
  
  } else {
    // call completion block with NO argument since the subscriber was not actually unsubscribed.
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(NO);
    });
  }
}

#pragma mark - OTSessionDelegate methods

- (void)sessionDidConnect:(OTSession*)session {
  
  NSLog(@"%s Connected [Connection: %@].", __PRETTY_FUNCTION__,session.connection.connectionId);
  NSLog(@"%s Connected [Connection data: %@].", __PRETTY_FUNCTION__,session.connection.data);
  NSLog(@"%s Connections [%d].", __PRETTY_FUNCTION__,session.connectionCount);
  NSLog(@"%s sessionId [%@].", __PRETTY_FUNCTION__, session.sessionId);
  NSLog(@"%s connectionStatus [%d].", __PRETTY_FUNCTION__, session.sessionConnectionStatus);
  NSLog(@"%s session [%@] self.session [%@].", __PRETTY_FUNCTION__, session, self.session);
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidConnect)]) {
      [self.delegate sessionDidConnect];
    }
  });
  
  // Optionnally publishing automatically once session is connected.
  if (self.autoPublish) {
    [self doPublish:@"sessionDidConnect"];
  }
}

- (void)sessionDidDisconnect:(OTSession*)session {
  NSLog(@"%s Disconnected [Session: %@].", __PRETTY_FUNCTION__, session);
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.disconnectCompletion)
      self.disconnectCompletion(YES);
    
    self.disconnectCompletion = nil;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidDisconnect)]) {
      [self.delegate sessionDidDisconnect];
    }
  });
  
  // This will reset the block properties of every connection objects, so make
  // sure you call it AFTER running the completion block...
  [self resetConnectionObjects:@"sessionDidDisconnect"];
}

- (void)session:(OTSession*)mySession streamCreated:(OTStream*)stream {
  NSLog(@"%s [Stream: %@, connectionId: %@, connection: %@].", __PRETTY_FUNCTION__, stream.streamId, stream.connection.connectionId, stream.connection);
  NSLog(@"%s _session.connection.connectionId: %@].", __PRETTY_FUNCTION__, _session.connection.connectionId);
  NSLog(@"%s Connection creationTime [%@].", __PRETTY_FUNCTION__, stream.connection.creationTime);
//  NSLog(@"%s Type [%@].", __PRETTY_FUNCTION__, stream.type);
  NSLog(@"%s Stream Created [%@].", __PRETTY_FUNCTION__, stream.creationTime);
  NSLog(@"%s Stream Name [%@].", __PRETTY_FUNCTION__, stream.name);
  NSLog(@"%s [Audio %@, Video %@].", __PRETTY_FUNCTION__, (stream.hasAudio ? @"YES" : @"NO"), (stream.hasVideo ? @"YES" : @"NO"));
  
  BOOL streamIsSelfPublishedStream = [stream.connection.connectionId isEqualToString: _session.connection.connectionId];
  
  NSLog(@"%s streamIsSelfPublishedStream: %d.", __PRETTY_FUNCTION__, streamIsSelfPublishedStream);
  
  // Subscribe to this stream if this is not our own publishing stream
  // Clearly here the logic is primitive and for strict early development purposes.
  if (!streamIsSelfPublishedStream && !_subscribeToSelf) {
    
    // If subscriber exists already, that means that we probably unpublished and republished,
    // in which case we need to close the subscriber before recreating a new one to subscribe to that stream.
    [self doUnsubscribeWithCompletion:^(BOOL success) {
      
      NSLog(@"%s Creating Subscriber for [Stream: %@].", __PRETTY_FUNCTION__,stream.streamId);
      
#if USES_OPENTOK_HIGH_LEVEL_API
      _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
#else
      _subscriber = [[TBExampleSubscriber alloc] initWithStream:stream delegate:self];
#endif
      OTError *error;
      [self.session subscribe:_subscriber error:&error];
      if (error) {
        NSLog(@"%s subscribe error: %@", __PRETTY_FUNCTION__, error);
      }
    } : @"session:didReceiveStream"];
    
  } else {
    NSLog(@"%s Skipping [Stream: %@].", __PRETTY_FUNCTION__,stream.streamId);
  }
}

- (void)session:(OTSession*)session streamDestroyed:(OTStream*)stream {
  NSLog(@"%s [%@, %@].", __PRETTY_FUNCTION__, stream, stream.streamId);
  
  if ([stream.streamId isEqualToString:self.subscriber.stream.streamId]) {
    // The stream we where subscribing to just dropped, reset subscriber object
    // as they may be now referencing a stale session.
    [self.subscriber.view removeFromSuperview];
    self.subscriber = nil;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidUnsubscribe)]) {
      [self.delegate sessionDidUnsubscribe];
    }
  }
}

- (void)session:(OTSession *)session connectionCreated:(OTConnection *)connection {
  NSLog(@"%s Other Connection Created [%@].", __PRETTY_FUNCTION__,connection.connectionId);
  NSLog(@"%s [Created at time: %@].", __PRETTY_FUNCTION__, connection.creationTime);
  NSLog(@"%s session.connectionCount [%d].", __PRETTY_FUNCTION__, session.connectionCount);
  NSLog(@"%s [session.streams %@].", __PRETTY_FUNCTION__, session.streams);
  NSLog(@"%s [session.streams count] [%d].", __PRETTY_FUNCTION__, [session.streams count]);
  
  // do I need to do anything here?
}

- (void) session:(OTSession *)session connectionDestroyed:(OTConnection *)connection {
  NSLog(@"%s Connection destroyed: [%@].", __PRETTY_FUNCTION__,connection.connectionId);
  NSLog(@"%s [Created: %@].", __PRETTY_FUNCTION__, connection.creationTime);
  NSLog(@"%s Connections [%d].", __PRETTY_FUNCTION__,session.connectionCount);
  
  [self doUnpublishWithCompletion:nil : @"session connectionDestroyed"];
  [self doUnsubscribeWithCompletion:nil : @"session connectionDestroyed"];
  
  if (self.delegate && [self.delegate respondsToSelector:@selector(sessionConnectionDidFailWithError:)]) {
    [self.delegate sessionConnectionDidFailWithError:nil];
  }
}

- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
  NSLog(@"%s [%@].", __PRETTY_FUNCTION__, error);
  NSLog(@"%s sessionId [%@].", __PRETTY_FUNCTION__, session.sessionId);
  
  // oh joy: you can get a bogus didFailWithError notication although your
  // sesssion will actually connect... So although it seems like resetting
  // connection objects and destroy the session is a good idea, one of these
  // calls here can corrupt the session and generate a crash.
  //  [self resetConnectionObjects:@"session:didFailWithError"];
  //  [self destroySessionObject];
  
  [self doUnpublishWithCompletion:nil : @"session didFailWithError"];
  [self doUnsubscribeWithCompletion:nil : @"session didFailWithError"];
  
  if (self.delegate && [self.delegate respondsToSelector:@selector(sessionConnectionDidFailWithError:)]) {
    [self.delegate sessionConnectionDidFailWithError:error];
  }
}


#pragma mark - OTPublisherDelegate methods

- (void)publisher:(OTPublisherKit *)publisher streamCreated:(OTStream *)stream {
  // Step 3b: (if YES == subscribeToSelf): Our own publisher is now visible to
  // all participants in the OpenTok session. We will attempt to subscribe to
  // our own stream. Expect to see a slight delay in the subscriber video and
  // an echo of the audio coming from the device microphone.
  if (nil == _subscriber && _subscribeToSelf) {
    NSLog(@"%s Subscribing To [Stream: %@].",__PRETTY_FUNCTION__, stream.streamId);
#if USES_OPENTOK_HIGH_LEVEL_API
    _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
#else
    _subscriber = [[TBExampleSubscriber alloc] initWithStream:stream delegate:self];
#endif
    OTError *error;
    [self.session subscribe:_subscriber error:&error];
    if (error) {
      NSLog(@"%s publish error %@", __PRETTY_FUNCTION__, error);
    }
  }
}

- (void)publisher:(OTPublisherKit*)publisher streamDestroyed:(OTStream*)stream {
  NSLog(@"%s [Name: %@].",__PRETTY_FUNCTION__, publisher.name);
  
  // if the unpublishCompletion block is not set, it might be that the publisher stream
  // was interrupted by an event that is not a local unpublish, which can happen is theory
  // I guess and should not be treated as an error.
  // It can also be a call from the unpublish button.
  if (self.unpublishCompletion) {
    // Run unpublishCompletion block.
    self.unpublishCompletion(YES);
    
    // Reset unpublishCompletion block.
    self.unpublishCompletion = nil;
  }
  
  // This is as late as I think I can null the publisher. Earlier might release it too
  // early and corrupt the session. We need clarify on the life cycle of opentok objects.
  _publisher = nil;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidUnpublish)]) {
      [self.delegate sessionDidUnpublish];
    }
  });
}

- (void)publisher:(OTPublisher*)publisher didFailWithError:(OTError*) error {
  
  NSLog(@"%s [%@].", __PRETTY_FUNCTION__,error);
  
  // I used to unpublish here but it's actually throwing a exception.
  // so now I just nil the publisher instead.
  
  _publisher = nil;
  if (self.delegate && [self.delegate respondsToSelector:@selector(sessionPublishingDidFailWithError:)]) {
    [self.delegate sessionPublishingDidFailWithError:error];
  }
}


#pragma mark - OTSubscriberDelegate methods

- (void)subscriberDidConnectToStream:(OTSubscriber*)subscriber {
  NSLog(@"%s [Stream: %@, Name: %@, Connection: %@].",__PRETTY_FUNCTION__,
        subscriber.stream.streamId, subscriber.stream.name,
        subscriber.stream.connection.connectionId);

  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidSubscribe)]) {
      [self.delegate sessionDidSubscribe];
    }
  });
}

- (void)subscriberVideoDataReceived:(OTSubscriber*)subscriber {
  //  NSLog(@"%s [Stream: %@, Name: %@]", __PRETTY_FUNCTION__, subscriber.stream.streamId,subscriber.stream.name);
}

- (void)subscriberVideoDisabled:(OTSubscriber*)subscriber {
  NSLog(@"%s [Stream: %@, Name: %@]", __PRETTY_FUNCTION__, subscriber.stream.streamId,subscriber.stream.name);
  UIView *greyingView = [[UIView alloc] initWithFrame:self.subscriber.view.frame];
  [greyingView setBackgroundColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:0.5]];
  [self.subscriber.view addSubview:greyingView];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [greyingView removeFromSuperview];
    [subscriber setSubscribeToVideo:YES];
  });
}


- (void)subscriber:(OTSubscriber*)subscriber didFailWithError:(OTError*)error {
  
  // The subscriber fails, so nil it so we don't have a reference dangling on what is
  // now a dead subscriber.
  [self.subscriber.view removeFromSuperview];
  _subscriber = nil;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionDidUnsubscribe)]) {
      [self.delegate sessionDidUnsubscribe];
    }
  });
}

- (void)stream:(OTStream *)stream didChangeVideoDimensions:(CGSize)dimensions {
  NSLog(@"%s dimensions:[%g, %g].", __PRETTY_FUNCTION__, dimensions.width, dimensions.height);
  
  // Trying to alievate side effects when video get downsized by poor network conditions.
  [_subscriber.view.superview layoutSubviews];
}

- (void)subscribeToFirstValidStreamFound:(NSString *)message {
  NSLog(@"%s:%@",__PRETTY_FUNCTION__, message);
  
  BOOL validStreamFound = NO;
  for (NSString* streamId in [[LEOOpenTokService sharedInstance] session].streams) {
    OTStream* stream = [[[LEOOpenTokService sharedInstance] session].streams valueForKey:streamId];
    NSLog(@"%s Inspecting [Stream: %@].",__PRETTY_FUNCTION__,streamId);
    if (![stream.connection.connectionId isEqualToString: _session.connection.connectionId]) {
      NSLog(@"%s Subscribing To [Stream: %@].",__PRETTY_FUNCTION__,streamId);
#if USES_OPENTOK_HIGH_LEVEL_API
      _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
#else
      _subscriber = [[TBExampleSubscriber alloc] initWithStream:stream delegate:self];
#endif
      OTError *error;
      [self.session subscribe:_subscriber error:&error];
      if (error) {
        NSLog(@"%s publish error %@", __PRETTY_FUNCTION__, error);
      }

      validStreamFound = YES;
      break;
    }
  }
  
  // This might be overly cautious, but it garantees that after calling this function
  // we do not have stale subscribers from dropped streams, which can crash the app.
  if (!validStreamFound) {
    [self.subscriber.view removeFromSuperview];
    _subscriber = nil;
  }
}


@end

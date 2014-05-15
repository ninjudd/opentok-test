Code demonstration of issues with Opentok 2.2beta3, special release for DaVinci Software

Project overview:
This is a project containing our implementation of integrating openTok 2.2 in our app packaged to be used in small demo app to provide OpenTok with repeatable scenario of the issues we are facing in our real app.

Top level are source and interface files (AppDelegate, ViewController, xib etc...) to implement the demo app itself.

Under the group DaVinciProductionCode are two files, LEOOpenTokService.[hm], which are actually copies of our production code integrating OpenTok.

This demo can use either the OTPublisher/OTSubscriber level api (like your demo app HelloWorld), or use subclasses of OTSubscriberKit/OTPublisherKit
by setting USES_OPENTOK_HIGH_LEVEL_API to either 0 or 1 in LEOOpenTokService.h

Under the group OpenTokExampleCode are copies of OpenTok source codes from their provided examples.

This demo can be used with one self subscribing iDevice of two mutually publishing and subscribing iDevices.

This new version tests the instancing of a GLKView, uses a pageviewcontroller to test usage of the main thread
during ramp up (do the page slide smoothly), and whether the views survive properly being hidden after
swiping them out of view.

I noticed that using OTPublisher/OTSubscriber is still imcompatible with a GLKView, as expected I guess.
Subclasses of OTSubscriberKit/OTPublisherKit are compatible with a GLKView which is essential to us so this
is where I focused my testing.

How to run demo app:
On top of ViewController.m, specify apikey and sessionId, and one or two tokens. 
If you specify only one token, running it on one device will be self subscribing.
To run on two devices talking to one another, specify two tokens and pick a different token with the segmented control on each device before starting the video session.




//
//  SHKFacebook.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/18/10.
//	3.0 SDK rewrite - Steven Troppoli 9/25/2012
//  3.16 SDK rewrite - Vilém Kurz 7/12/2014
//  4.2 SDK rewrite – Alexandr Chaplyuk 8/6/2015

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SHKFacebook.h"

#import "SHKFacebookCommon.h"
#import "SharersCommonHeaders.h"

#import "NSMutableDictionary+NSNullsToEmptyStrings.h"
#import "NSHTTPCookieStorage+DeleteForURL.h"

#import "FBSDKCoreKit/FBSDKCoreKit.h"
#import "FBSDKLoginKit/FBSDKLoginKit.h"


#define PUBLISH_PERMISSION @"publish_actions"


@interface SHKFacebook ()

///reference of an upload connection, so that it is cancellable (used in file/image uploads, which can report progress)
@property (nonatomic, weak) FBSDKGraphRequestConnection *fbRequestConnection;

@end

@implementation SHKFacebook

#pragma mark - 
#pragma mark Initialization

+ (void)setupFacebookSDK {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[FBSDKSettings setAppID:SHKCONFIG(facebookAppId)];
		[FBSDKSettings setAppURLSchemeSuffix:SHKCONFIG(facebookLocalAppId)];
		[FBSDKProfile enableUpdatesOnAccessTokenChange:YES];
	});
}
- (instancetype)init {
    self = [super init];
    if (self) {
        
        [SHKFacebook setupFacebookSDK];
    }
    return self;
}

#pragma mark -
#pragma mark App lifecycle

+ (void)handleDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[SHKFacebook setupFacebookSDK];
	[[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication]
							 didFinishLaunchingWithOptions:launchOptions];
}

+ (void)handleDidBecomeActive
{
    [SHKFacebook setupFacebookSDK];
	// Call the 'activateApp' method to log an app event for use
	// in analytics and advertising reporting.
    [FBSDKAppEvents activateApp];
}

+ (BOOL)handleOpenURL:(NSURL*)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	[SHKFacebook setupFacebookSDK];
    
	BOOL result = [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication]
																 openURL:url
													   sourceApplication:sourceApplication
															  annotation:annotation];
	
	/*
    SHKFacebook *facebookSharer = [[SHKFacebook alloc] init];
    BOOL itemRestored = [facebookSharer restoreItem];
    
    if (itemRestored) {
        FBSessionStateHandler handler = ^(FBSession *session, FBSessionState status, NSError *error) {
            
            if (error) {
                [facebookSharer saveItemForLater:facebookSharer.pendingAction];
                SHKLog(@"no read permissions: %@", [error description]);
            } else {
                
                //this allows for completion block to finish and continue sharing AFTER. Otherwise strange black windows and orphan webview login showed up.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [facebookSharer tryPendingAction];
                });
            }
        };
        
        if ([[FBSession activeSession] isOpen]) {
            handler([FBSession activeSession], [FBSession activeSession].state, nil);
        } else {
            NSRange rangeOfWritePermissions = [[url absoluteString] rangeOfString:SHKCONFIG(facebookWritePermissions)[0]];
            BOOL gotReadPermissionsOnly =  rangeOfWritePermissions.location == NSNotFound;
            if (gotReadPermissionsOnly) {
                [FBSession openActiveSessionWithReadPermissions:SHKCONFIG(facebookReadPermissions) allowLoginUI:NO completionHandler:handler];
            } else {
                [FBSession openActiveSessionWithPublishPermissions:SHKCONFIG(facebookWritePermissions) defaultAudience:FBSessionDefaultAudienceFriends allowLoginUI:NO completionHandler:handler];
            }
        }
    }
	*/

    return result;
}

#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return SHKLocalizedString(@"Facebook");
}

+ (BOOL)canShareURL
{
	return YES;
}

+ (BOOL)canShareText
{
	return YES;
}

+ (BOOL)canShareImage
{
	return YES;
}

+ (BOOL)canShareFile:(SHKFile *)file
{
    BOOL result = [SHKFacebookCommon canFacebookAcceptFile:file];
    return result;
}

+ (BOOL)canShareOffline
{
	return NO; // TODO - would love to make this work
}

+ (BOOL)canGetUserInfo
{
    return NO;
}

+ (BOOL)canShare {
    return YES;
}

#pragma mark -
#pragma mark Authentication

- (BOOL)isAuthorized
{
	//SHKLog(@"session is authorized: %@", [FBSDKAccessToken currentAccessToken]);
    BOOL result = ([FBSDKAccessToken currentAccessToken] != nil);
    return result;
}

- (void)promptAuthorization
{
    [self saveItemForLater:SHKPendingShare];

	// https://developers.facebook.com/docs/facebook-login/permissions/v2.3#optimizing

	void (^requestWritePermissions)() = ^{
		SHKLog(@"Request write permissions");
		[[self.class loginManager] logInWithPublishPermissions:SHKCONFIG(facebookWritePermissions) handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
			SHKFacebook *facebookSharer = [SHKFacebook new];

			if (!error && !result.isCancelled) {
				SHKLog(@"Write permissions Success!");
				[facebookSharer authDidFinish:YES];
			}
			else {
				SHKLog(@"Write permissions FAIL!");
				[facebookSharer authDidFinish:NO];
			}
		}];
	};

	if (![self.class hasGrantedOrDeclined:SHKCONFIG(facebookReadPermissions)]) {
		SHKLog(@"Request read permissions");
		[[self.class loginManager] logInWithReadPermissions:SHKCONFIG(facebookReadPermissions) handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
			if (!error && !result.isCancelled) {
				SHKLog(@"Read permissions Success!");
				requestWritePermissions();
			}
			else {
				SHKLog(@"Read permissions FAIL!");
				SHKFacebook *facebookSharer = [SHKFacebook new];
				[facebookSharer authDidFinish:NO];
			}
		}];
	}
	else if (![self.class hasGrantedOrDeclined:SHKCONFIG(facebookWritePermissions)]) {
		requestWritePermissions();
	}
}

+ (NSString *)username {
	return [[FBSDKProfile currentProfile] name];
}

+ (void)logout
{
	[SHKFacebook clearSavedItem];
	[[FBSDKLoginManager new] logOut];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSHKFacebookUserInfo];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSHKFacebookVideoUploadLimits];
}


#pragma mark -
#pragma mark Share Form
- (NSArray *)shareFormFieldsForType:(SHKShareType)type
{
    NSArray *result = [SHKFacebookCommon shareFormFieldsForItem:self.item];
    return result;
}

- (BOOL)send {
    if (![self validateItem])
		return NO;

    // Ask for publish_actions permissions in context
	if (self.item.shareType != SHKShareTypeUserInfo && ![self.class hasGranted:@[PUBLISH_PERMISSION]]) { // we need at least this
        // No permissions found in session, ask for it
        [self saveItemForLater:SHKPendingSend];
        [self displayActivity:SHKLocalizedString(@"Authenticating...")];

		[[FBSDKLoginManager new] logInWithPublishPermissions:SHKCONFIG(facebookWritePermissions) handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
			[self restoreItem];
			[self hideActivityIndicator];

			if (error) {
				UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
																	message:error.localizedDescription
																   delegate:nil
														  cancelButtonTitle:@"OK"
														  otherButtonTitles:nil];
				[alertView show];

				// flip back to here so they can cancel
				self.pendingAction = SHKPendingShare;
				[self tryPendingAction];
			}
			else if (result.isCancelled) {
				[self sendDidCancel];
			}
			else {
				if ([self.class hasGranted:@[PUBLISH_PERMISSION]]) {
					// If permissions granted, publish the story
					[self doSend];
				}
				else {
					// TODO: Show the alert about required (and not granted) permissions

					// Permission has not granted, flip back to here so they can cancel
					self.pendingAction = SHKPendingShare;
					[self tryPendingAction];
				}
			}
			// the session watcher handles the error
		}];
    }
	else {
        // If permissions present, publish the story
        [self doSend];
    }

    return YES;
}

- (void)doSend
{
	NSMutableDictionary *params = [SHKFacebookCommon composeParamsForItem:self.item];

	if (self.item.shareType == SHKShareTypeURL || self.item.shareType == SHKShareTypeText) {
		FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/feed"
																	   parameters:params
																	   HTTPMethod:@"POST"];
		[request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
			[self FBRequestHandlerCallback:connection result:result error:error];
		}];
	}
	else if (self.item.shareType == SHKShareTypeImage) {
        /*if (self.item.title)
         [params setObject:self.item.title forKey:@"caption"];*/ //caption apparently does not work
		[params setObject:self.item.image forKey:@"picture"];
		// There does not appear to be a way to add the photo
		// via the dialog option:
		FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/photos"
																	   parameters:params
																	   HTTPMethod:@"POST"];
		self.fbRequestConnection = [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
			[self FBRequestHandlerCallback:connection result:result error:error];
		}];
		self.fbRequestConnection.delegate = self;
	}
    else if (self.item.shareType == SHKShareTypeFile) {
        [self validateVideoLimits:^(NSError *error){
            
            if (error){
                [self hideActivityIndicator];
                [self sendDidFailWithError:error];
                [self sendDidFinish];
                return;
            }
            
            [params setObject:self.item.file.data forKey:self.item.file.filename];
            [params setObject:self.item.file.mimeType forKey:@"contentType"];
			FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/videos"
																		   parameters:params
																		   HTTPMethod:@"POST"];
			self.fbRequestConnection = [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
				[self FBRequestHandlerCallback:connection result:result error:error];
			}];
			self.fbRequestConnection.delegate = self;
        }];
	}

    [self sendDidStart];
}

- (void)cancel {
    [self.fbRequestConnection cancel];
    [self sendDidCancel];
}

- (void)FBRequestHandlerCallback:(FBSDKGraphRequestConnection *)connection
						  result:(id)result
						   error:(NSError *)error {
	if (error) {
		[self hideActivityIndicator];

		if (error.code == 190 || error.code == 403) {
			// TODO: Renew account credentials other way
//			[FBSession.activeSession closeAndClearTokenInformation];
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:kSHKFacebookUserInfo];
			[self shouldReloginWithPendingAction:SHKPendingSend];
		} else {
			[self sendDidFailWithError:error];
		}
	}
	else {
		[self sendDidFinish];
	}
}

-(void)validateVideoLimits:(void (^)(NSError *error))completionBlock
{
    // Validate against video size restrictions
    
    // Pull our constraints directly from facebook
	FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me?fields=video_upload_limits"
																   parameters:nil];
	[request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
        if(error){
            [self hideActivityIndicator];
            [self sendDidFailWithError:error];
            
            return;
        }else{
            // Parse and store - for possible future reference
            [result convertNSNullsToEmptyStrings];
            [[NSUserDefaults standardUserDefaults] setObject:result forKey:kSHKFacebookVideoUploadLimits];
            
            // Check video size
            NSUInteger maxVideoSize = [result[@"video_upload_limits"][@"size"] unsignedIntegerValue];
            BOOL isUnderSize = maxVideoSize >= self.item.file.size;
            if(!isUnderSize){
                completionBlock([NSError errorWithDomain:@"video_upload_limits" code:200 userInfo:@{
                                                                                                    NSLocalizedDescriptionKey:SHKLocalizedString(@"Video's file size is too large for upload to Facebook.")}]);
                return;
            }
            
            // Check video duration
            NSNumber *maxVideoDuration = result[@"video_upload_limits"][@"length"];
            BOOL isUnderDuration = [maxVideoDuration integerValue] >= self.item.file.duration;
            if(!isUnderDuration){
                completionBlock([NSError errorWithDomain:@"video_upload_limits" code:200 userInfo:@{
                                                                                                    NSLocalizedDescriptionKey:SHKLocalizedString(@"Video's duration is too long for upload to Facebook.")}]);
                return;
            }
            
            // Success!
            completionBlock(nil);
        }
    }];
}

- (void)FBUserInfoRequestHandlerCallback:(FBSDKGraphRequestConnection *)connection
								  result:(id)result
								   error:(NSError *)error
{
	if (error) {
        SHKLog(@"FB user info request failed with error:%@", error);
        return;
    }
    
    [result convertNSNullsToEmptyStrings];
    [[NSUserDefaults standardUserDefaults] setObject:result forKey:kSHKFacebookUserInfo];
    [self sendDidFinish];
    [[SHK currentHelper] removeSharerReference:self];
}

#pragma mark - FBRequestConnectionDelegate methods

- (void)requestConnection:(FBSDKGraphRequestConnection *)connection
		  didSendBodyData:(NSInteger)bytesWritten
		totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    [self showUploadedBytes:totalBytesWritten totalBytes:totalBytesExpectedToWrite];
}

#pragma mark -

+ (FBSDKLoginManager *)loginManager {
	FBSDKLoginManager *manager = [FBSDKLoginManager new];
	manager.loginBehavior = ([SHKFacebookCommon socialFrameworkAvailable]) ? FBSDKLoginBehaviorSystemAccount : FBSDKLoginBehaviorNative;
	return manager;
}

+ (BOOL)hasGranted:(NSArray *)permissions {
	// All granted permissions granted by account owner
	FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
	NSSet *userPermissions = accessToken.permissions;

	return [[NSSet setWithArray:permissions] isSubsetOfSet:userPermissions];
}

+ (BOOL)hasGrantedOrDeclined:(NSArray *)permissions {
	// All defined permissions (granted or declined) by account owner
	// Including `declinedPermissions` breaks permission requesting loop
	//   when the app is asking for declined permission again and again
	FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
	NSMutableSet *userPermissions = [NSMutableSet setWithSet:accessToken.permissions];
	[userPermissions unionSet:accessToken.declinedPermissions];

	return [[NSSet setWithArray:permissions] isSubsetOfSet:userPermissions];
}

@end

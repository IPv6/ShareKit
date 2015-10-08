//
//  SHKTwitterUniversal.m
//  ShareKit
//
//  Created by Krin-San on 10.06.15.
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

#import "SHKTwitterUniversal.h"
#import "SHKTwitterCommon.h"
#import "Debug.h"

#import <Accounts/Accounts.h>


@implementation SHKTwitterUniversal

static NSMutableArray *_retainContainer = nil;

#pragma mark - Core

+ (void)sharerClassWithCompletion:(void (^)(__unsafe_unretained Class class))completion {
	ACAccountStore *accountStore = [ACAccountStore new];
	ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:self.accountTypeIdentifier];

	if (![SHKTwitterCommon socialFrameworkAvailable] || accountStore == nil) {
		Class class = SHKTwitter.class;
		SHKLog(@"Twitter sharer class (fallback): %@", NSStringFromClass(class));
		completion(class);
		return;
	}

	// AccountStore must be retained until it returns any result in completions block
	[self.retainContainer addObject:accountStore];
	[accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
		Class class = nil;

		if (granted && [self hasAtLeastOneAccount]) {
			class = SHKiOSTwitter.class;
		}
		else {
			// Including condition (error.code == ACErrorAccountNotFound)
			class = SHKTwitter.class;
		}

		[self.retainContainer removeObject:accountStore];
		SHKLog(@"Twitter sharer class: %@", NSStringFromClass(class));
		completion(class);
	}];
}

+ (BOOL)canShareItem:(SHKItem *)item {
	return ([SHKiOSTwitter canShareItem:item] && [SHKTwitter canShareItem:item]);
}

+ (id)shareItem:(SHKItem *)i {
	[self sharerClassWithCompletion:^(__unsafe_unretained Class class) {
		[class shareItem:i];
	}];
	return nil;
}

+ (BOOL)isServiceAuthorized {
	BOOL system = [SHKiOSTwitter isServiceAuthorized] && [self hasAtLeastOneAccount];
	BOOL web    = [SHKTwitter isServiceAuthorized];
	SHKLog(@"System = %i, Web = %i", system, web);
	return (system || web);
}

+ (BOOL)canShare {
	return YES;
}

+ (NSString *)username {
	NSString *systemUsername = [SHKiOSTwitter username];
	NSString *webUsername    = [SHKTwitter username];
	return (systemUsername.length > 0) ? systemUsername : webUsername;
}

+ (void)logout {
	[SHKiOSTwitter logout];
	[SHKTwitter logout];
}

#pragma mark - Lazy

+ (NSMutableArray *)retainContainer {
	if (!_retainContainer) {
		_retainContainer = [NSMutableArray array];
	}
	return _retainContainer;
}

#pragma mark -

+ (NSString *)accountTypeIdentifier {
	return ACAccountTypeIdentifierTwitter;
}

+ (BOOL)hasAtLeastOneAccount {
	ACAccountStore *accountStore = [ACAccountStore new];
	ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:self.accountTypeIdentifier];
	NSUInteger count = [accountStore accountsWithAccountType:accountType].count;
	return (count > 0);
}

@end

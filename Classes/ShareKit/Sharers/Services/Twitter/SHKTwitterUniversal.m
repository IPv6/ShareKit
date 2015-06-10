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

@interface SHKTwitterUniversal ()
@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, strong) ACAccountType  *accountType;
@end


@implementation SHKTwitterUniversal

- (void)sharerClassWithCompletion:(void (^)(Class class))completion {
	if (![SHKTwitterCommon socialFrameworkAvailable] || self.accountStore == nil) {
		completion(SHKTwitter.class);
		SHKLog(@"Callback to %@", NSStringFromClass(class));
		return;
	}

	[self.accountStore requestAccessToAccountsWithType:self.accountType options:nil completion:^(BOOL granted, NSError *error) {
		Class class = (error.code == ACErrorAccountNotFound) ? SHKTwitter.class : SHKiOSTwitter.class;
		SHKLog(@"Result class %@", NSStringFromClass(class));
		completion(class);
	}];
}

+ (void)logOut {
	[SHKTwitter logout];
	[SHKiOSTwitter logout];
}

#pragma mark - Lazy

- (ACAccountStore *)accountStore {
	if (!_accountStore) {
		_accountStore = [ACAccountStore new];
	}
	return _accountStore;
}

- (ACAccountType *)accountType {
	if (!_accountType) {
		_accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:self.accountTypeIdentifier];
	}
	return _accountType;
}

#pragma mark -

- (NSString *)accountTypeIdentifier {
	return ACAccountTypeIdentifierTwitter;
}

@end

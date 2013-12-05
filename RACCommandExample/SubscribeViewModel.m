//
//  Created by Ole Gammelgaard Poulsen on 05/12/13.
//  Copyright (c) 2012 SHAPE A/S. All rights reserved.
//

#import "SubscribeViewModel.h"
#import "AFHTTPRequestOperationManager.h"
#import "AFHTTPRequestOperationManager+RACSupport.h"


static NSString *const kSubscribeURL = @"http://reactivetest.apiary.io/subscribers";

@interface SubscribeViewModel ()

@property(nonatomic, strong) RACSignal *emailValidSignal;

@end

@implementation SubscribeViewModel {

}

- (id)init {
	self = [super init];
	if (self) {

		[self mapSubscribeCommandStateToStatusMessage];
	}
	return self;
}

- (void)mapSubscribeCommandStateToStatusMessage {
	RACSignal *startedMessageSource = [self.subscribeCommand.executionSignals map:^id(id value) {
		return NSLocalizedString(@"Sending request...", nil);
	}];

	RACSignal *completedMessageSource = [self.subscribeCommand.executionSignals flattenMap:^RACStream *(RACSignal *subscribeSignal) {
		return [[[subscribeSignal materialize] filter:^BOOL(RACEvent *event) {
			return event.eventType == RACEventTypeCompleted;
		}] map:^id(id value) {
			return NSLocalizedString(@"Thanks", nil);
		}];
	}];

	RACSignal *failedMessageSource = [[self.subscribeCommand.errors subscribeOn:[RACScheduler mainThreadScheduler]] map:^id(NSError *error) {
		return NSLocalizedString(@"Error :(", nil);
	}];

	RAC(self, statusMessage) = [RACSignal merge:@[startedMessageSource, completedMessageSource, failedMessageSource]];
}

- (RACCommand *)subscribeCommand {
	if (!_subscribeCommand) {
		NSString *email = self.email;
		_subscribeCommand = [[RACCommand alloc] initWithEnabled:self.emailValidSignal signalBlock:^RACSignal *(id input) {
			RACSignal *subscribeSignal = [SubscribeViewModel postEmail:email];
			return subscribeSignal;
		}];
	}
	return _subscribeCommand;
}

+ (RACSignal *)postEmail:(NSString *)email {
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	manager.requestSerializer = [AFJSONRequestSerializer new];
	NSDictionary *body = @{@"email": email ?: @""};
	return [[[manager rac_POST:kSubscribeURL parameters:body] logError] replayLazily];
}

- (RACSignal *)emailValidSignal {
	if (!_emailValidSignal) {
		_emailValidSignal = [RACObserve(self, email) map:^id(NSString *email) {
			if (!email) return @NO;
			NSString *emailPattern =
					@"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
							@"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
							@"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
							@"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
							@"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
							@"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
							@"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
			NSError *error = nil;
			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:emailPattern options:NSRegularExpressionCaseInsensitive error:&error];
			NSTextCheckingResult *match = [regex firstMatchInString:email options:0 range:NSMakeRange(0, [email length])];
			return @(match != nil);
		}];
	}
	return _emailValidSignal;
}

@end
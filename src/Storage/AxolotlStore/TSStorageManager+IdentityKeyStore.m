//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "NSDate+millisecondTimeStamp.h"
#import "TSAccountManager.h"
#import "TSContactThread.h"
#import "TSErrorMessage.h"
#import "TSPrivacyPreferences.h"
#import "TSStorageManager+IdentityKeyStore.h"
#import <Curve25519/Curve25519.h>

#define TSStorageManagerIdentityKeyStoreIdentityKey \
    @"TSStorageManagerIdentityKeyStoreIdentityKey" // Key for our identity key
#define TSStorageManagerIdentityKeyStoreCollection @"TSStorageManagerIdentityKeyStoreCollection"
#define TSStorageManagerTrustedKeysCollection @"TSStorageManagerTrustedKeysCollection"


@implementation TSStorageManager (IdentityKeyStore)

- (void)generateNewIdentityKey {
    [self setObject:[Curve25519 generateKeyPair]
              forKey:TSStorageManagerIdentityKeyStoreIdentityKey
        inCollection:TSStorageManagerIdentityKeyStoreCollection];
}


- (NSData *)identityKeyForRecipientId:(NSString *)recipientId {
    return [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];
}


- (ECKeyPair *)identityKeyPair {
    return [self keyPairForKey:TSStorageManagerIdentityKeyStoreIdentityKey
                  inCollection:TSStorageManagerIdentityKeyStoreCollection];
}

- (int)localRegistrationId {
    return (int)[TSAccountManager getOrGenerateRegistrationId];
}

- (void)saveRemoteIdentity:(NSData *)identityKey recipientId:(NSString *)recipientId {
    [self setObject:identityKey forKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];
}

- (BOOL)isTrustedIdentityKey:(NSData *)identityKey recipientId:(NSString *)recipientId {
    NSData *existingKey = [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];

    if (!existingKey) {
        return YES;
    }

    if ([existingKey isEqualToData:identityKey]) {
        return YES;
    }

    if (self.privacyPreferences.shouldBlockOnIdentityChange) {
        return NO;
    }

    DDLogInfo(@"Updating identity key for recipient:%@", recipientId);
    [self createIdentityChangeInfoMessageForRecipientId:recipientId];
    [self saveRemoteIdentity:identityKey recipientId:recipientId];
    return YES;
}

- (void)removeIdentityKeyForRecipient:(NSString *)receipientId {
    [self removeObjectForKey:receipientId inCollection:TSStorageManagerTrustedKeysCollection];
}

- (void)createIdentityChangeInfoMessageForRecipientId:(NSString *)recipientId
{
    TSContactThread *contactThread = [TSContactThread getOrCreateThreadWithContactId:recipientId];
    [[[TSErrorMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                      inThread:contactThread
                             failedMessageType:TSErrorMessageNonBlockingIdentityChange] save];
}

@end

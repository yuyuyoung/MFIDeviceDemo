//
//  RMExternalAccessoryManager.h
//  LiveApp
//
//  Created by Yu Young on 2024/7/16.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>

#define EADSessionDataReceivedNotification @"EADSessionDataReceivedNotification"

NS_ASSUME_NONNULL_BEGIN

@interface RMExternalAccessoryManager : NSObject

+(instancetype)sharedManager;

- (void)registerManager;
- (void)closeSession;

- (void)writeData:(NSData *)data;

- (NSUInteger)readBytesAvailable;
- (NSData *)readData:(NSUInteger)bytesToRead;

@end

NS_ASSUME_NONNULL_END

//
//  RMExternalAccessoryManager.m
//  LiveApp
//
//  Created by Yu Young on 2024/7/16.
//

#import "RMExternalAccessoryManager.h"
#import <CarPlay/CarPlay.h>

#define RMExternalAccessoryProtocol_EAP @"com.remo.prot0"
#define RMExternalAccessoryProtocol_NAV @"com.remo.camera"

@interface RMExternalAccessoryManager () <EAAccessoryDelegate, NSStreamDelegate>

@property (nonatomic, strong) EASession *eap_session;
@property (nonatomic, strong) EASession *nav_session;

@property (nonatomic, strong) EAAccessory *accessory;
@property (nonatomic, strong) NSMutableData *writeData;
@property (nonatomic, strong) NSMutableData *readData;

@end

@implementation RMExternalAccessoryManager

static RMExternalAccessoryManager * _instance = nil;
 
+(instancetype)sharedManager
{
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init] ;
    }) ;
    
    return _instance ;
}

#pragma mark Internal

- (void)_writeData {
    NSMutableData *eap_data = [NSMutableData dataWithData:_writeData];
    NSLog(@">>>>>>>>>>write data to mfi device %@", _writeData);
    NSLog(@">>>>>>>>>>_eap_session to hasSpaceAvailable %@", [[_eap_session outputStream] hasSpaceAvailable] ? @"yes" : @"No");
    while (([[_eap_session outputStream] hasSpaceAvailable]) && ([eap_data length] > 0))
    {
        NSInteger bytesWritten = [[_eap_session outputStream] write:[eap_data bytes] maxLength:[eap_data length]];
        if (bytesWritten == -1)
        {
            NSLog(@"write error");
            break;
        }
        else if (bytesWritten > 0)
        {
            [eap_data replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
            NSLog(@"bytesWritten %ld", (long)bytesWritten);

        }
    }
    
    NSMutableData *nav_data = [NSMutableData dataWithData:_writeData];
    NSLog(@">>>>>>>>>>_nav_session to hasSpaceAvailable %@", [[_nav_session outputStream] hasSpaceAvailable] ? @"yes" : @"No");
    while (([[_nav_session outputStream] hasSpaceAvailable]) && ([nav_data length] > 0))
    {
        NSInteger bytesWritten = [[_nav_session outputStream] write:[nav_data bytes] maxLength:[nav_data length]];
        if (bytesWritten == -1)
        {
            NSLog(@"write error");
            break;
        }
        else if (bytesWritten > 0)
        {
            [nav_data replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
            NSLog(@"bytesWritten %ld", (long)bytesWritten);
        }
    }
    _writeData = nil;
}

- (void)_readData {
    #define EAD_INPUT_BUFFER_SIZE 128
//    uint8_t buf[EAD_INPUT_BUFFER_SIZE];
    uint8_t buf2[EAD_INPUT_BUFFER_SIZE];
    
//    while ([[_eap_session inputStream] hasBytesAvailable])
//    {
//        NSInteger bytesRead = [[_eap_session inputStream] read:buf maxLength:EAD_INPUT_BUFFER_SIZE];
//        if (_readData == nil) {
//            _readData = [[NSMutableData alloc] init];
//        }
//        [_readData appendBytes:(void *)buf length:bytesRead];
//        NSLog(@"read %ld bytes from eap_session input stream", (long)bytesRead);
//    }
//
//    NSString *eap_string = [[NSString alloc] initWithData:_readData encoding:NSASCIIStringEncoding];
//    
    
    _readData = nil;
    while ([[_nav_session inputStream] hasBytesAvailable])
    {
        NSInteger bytesRead = [[_nav_session inputStream] read:buf2 maxLength:EAD_INPUT_BUFFER_SIZE];
        if (_readData == nil) {
            _readData = [[NSMutableData alloc] init];
        }
        [_readData appendBytes:(void *)buf2 length:bytesRead];
        NSLog(@"read %ld bytes from nav_session input stream", (long)bytesRead);
    }

    NSString *nav_string = [[NSString alloc] initWithData:_readData encoding:NSASCIIStringEncoding];
    
    
    NSString *str = [NSString stringWithFormat:@"nav_data: %@", nav_string];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kExternalAccessoryDataKey" object:nav_string];
    NSLog(@"接收到数据%@", str);
}

- (void)dealloc
{
    [self closeSession];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
}


- (void)registerManager {
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
    
    [self searchOurAccessory];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:EAAccessoryDidConnectNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [self searchOurAccessory];
    }];
}


- (void)searchOurAccessory {
    // search our device
    NSLog(@"当前检测到外接MFI设备个数为%d", (int)[[EAAccessoryManager sharedAccessoryManager] connectedAccessories].count);
    for (EAAccessory *accessory in [[EAAccessoryManager sharedAccessoryManager] connectedAccessories]) {
        if ([accessory.protocolStrings containsObject:RMExternalAccessoryProtocol_EAP] || [accessory.protocolStrings containsObject:RMExternalAccessoryProtocol_NAV]) {
            if (!self.accessory) {
                self.accessory = accessory;
                [_accessory setDelegate:self];
                [self openEapSession];
                [self openNavSession];
            }
        }
    }
}

- (BOOL)openEapSession
{
    _eap_session = [[EASession alloc] initWithAccessory:_accessory forProtocol:RMExternalAccessoryProtocol_EAP];
    
    if (_eap_session)
    {
        [[_eap_session inputStream] setDelegate:self];
        [[_eap_session inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_eap_session inputStream] open];

        [[_eap_session outputStream] setDelegate:self];
        [[_eap_session outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_eap_session outputStream] open];
    }
    return (_eap_session != nil);
}

- (BOOL)openNavSession
{
    _nav_session = [[EASession alloc] initWithAccessory:_accessory forProtocol:RMExternalAccessoryProtocol_NAV];

    if (_nav_session)
    {
        [[_nav_session inputStream] setDelegate:self];
        [[_nav_session inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_nav_session inputStream] open];

        [[_nav_session outputStream] setDelegate:self];
        [[_nav_session outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_nav_session outputStream] open];
    }
    return (_nav_session != nil);
}


- (void)closeSession
{
    [[_eap_session inputStream] close];
    [[_eap_session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_eap_session inputStream] setDelegate:nil];
    [[_eap_session outputStream] close];
    [[_eap_session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_eap_session outputStream] setDelegate:nil];
    
    [[_nav_session inputStream] close];
    [[_nav_session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_nav_session inputStream] setDelegate:nil];
    [[_nav_session outputStream] close];
    [[_nav_session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_nav_session outputStream] setDelegate:nil];

    _eap_session = nil;
    _nav_session = nil;

    _writeData = nil;
    _readData = nil;
    
    [_accessory setDelegate:nil];
    _accessory = nil;
}

- (void)writeData:(NSData *)data
{
    if (_writeData == nil) {
        _writeData = [[NSMutableData alloc] init];
    }
    NSLog(@">>>>>>>>>>用户点击发送数据");
    [_writeData appendData:data];
    [self _writeData];
}

- (NSData *)readData:(NSUInteger)bytesToRead
{
    NSData *data = nil;
    if ([_readData length] >= bytesToRead) {
        NSRange range = NSMakeRange(0, bytesToRead);
        data = [_readData subdataWithRange:range];
        [_readData replaceBytesInRange:range withBytes:NULL length:0];
    }
    return data;
}

- (NSUInteger)readBytesAvailable
{
    return [_readData length];
}

#pragma mark - EAAccessoryDelegate

- (void)accessoryDidDisconnect:(EAAccessory *)accessory {
    NSLog(@"DidDisconnect");
    [self closeSession];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventNone:
            break;
        case NSStreamEventOpenCompleted:
            break;
        case NSStreamEventHasBytesAvailable:
            [self _readData];
            break;
        case NSStreamEventHasSpaceAvailable:
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@">>>>>>>>>>NSStreamEventErrorOccurred");
            break;
        case NSStreamEventEndEncountered:
            NSLog(@">>>>>>>>>>NSStreamEventEndEncountered");
            break;
        default:
            break;
    }
}

@end

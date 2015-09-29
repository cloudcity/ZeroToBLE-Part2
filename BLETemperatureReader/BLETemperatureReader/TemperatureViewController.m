//
//  TemperatureViewController.m
//  BLETemperatureReader
//
//  Created by Evan Stone on 8/7/15.
//  Copyright (c) 2015 Cloud City. All rights reserved.
//

#import "TemperatureViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "Constants.h"

#define TIMER_PAUSE_INTERVAL 10.0
#define TIMER_SCAN_INTERVAL  2.0

#define SENSOR_DATA_INDEX_TEMP_INFRARED 0
#define SENSOR_DATA_INDEX_TEMP_AMBIENT  1
#define SENSOR_DATA_INDEX_HUMIDITY_TEMP 0
#define SENSOR_DATA_INDEX_HUMIDITY      1

// This could be simplified to "SensorTag" and check if it's a substring...
#define SENSOR_TAG_NAME @"CC2650 SensorTag"


@interface TemperatureViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

// Properties for Background Swapping
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView1;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView2;
@property (nonatomic, strong) NSArray *backgroundImageViews;
@property (nonatomic, assign) NSInteger visibleBackgroundIndex;
@property (nonatomic, assign) NSInteger invisibleBackgroundIndex;
@property (nonatomic, assign) NSInteger lastTemperatureTens;

@property (weak, nonatomic) IBOutlet UIView *controlContainerView;
@property (weak, nonatomic) IBOutlet UIView *circleView;
@property (weak, nonatomic) IBOutlet UILabel *captionLabel;
@property (weak, nonatomic) IBOutlet UILabel *temperatureLabel;
@property (weak, nonatomic) IBOutlet UILabel *humidityLabel;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *sensorTag;
@property (nonatomic, assign) BOOL keepScanning;

@end

@implementation TemperatureViewController {
    BOOL circleDrawn;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Create the CBCentralManager.
    // NOTE: Creating the CBCentralManager with initWithDelegate will immediately call centralManagerDidUpdateState.
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
    
    // configure our initial UI
    self.captionLabel.hidden = YES;
    self.temperatureLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:56];
    self.temperatureLabel.text = @"Searching";
    self.humidityLabel.text = @"";

    circleDrawn = NO;
    self.circleView.hidden = YES;
    self.lastTemperatureTens = 0;
    self.visibleBackgroundIndex = 0;
    self.invisibleBackgroundIndex = 1;
    self.backgroundImageViews = [NSArray arrayWithObjects:self.backgroundImageView1, self.backgroundImageView2, nil];
    [self.view bringSubviewToFront:(UIView *)self.backgroundImageViews[self.visibleBackgroundIndex]];
    ((UIView *)self.backgroundImageViews[self.visibleBackgroundIndex]).alpha = 1;
    ((UIView *)self.backgroundImageViews[self.invisibleBackgroundIndex]).alpha = 0;
    [self.view bringSubviewToFront:self.controlContainerView];
}

- (void)pauseScan {
    // Scanning uses up battery on phone, so pause the scan process for the designated interval.
    NSLog(@"*** PAUSING SCAN...");
    [NSTimer scheduledTimerWithTimeInterval:TIMER_PAUSE_INTERVAL target:self selector:@selector(resumeScan) userInfo:nil repeats:NO];
    [self.centralManager stopScan];
}

- (void)resumeScan {
    if (self.keepScanning) {
        // Start scanning again...
        NSLog(@"*** RESUMING SCAN!");
        [NSTimer scheduledTimerWithTimeInterval:TIMER_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
}

- (void)cleanup {
    [_centralManager cancelPeripheralConnection:self.sensorTag];
}


#pragma mark - Updating UI

- (void)displayTemperature:(NSData *)dataBytes {
    if (!circleDrawn) {
        [self drawCircle];
    }
    
    // get the data's length - divide by two since we're creating an array that holds 16-bit (two-byte) values...
    NSUInteger dataLength = dataBytes.length / 2;
    
    // create an array to contain the 16-bit values
    uint16_t dataArray[dataLength];
    for (int i = 0; i < dataLength; i++) {
        dataArray[i] = 0;
    }
    
    // extract the data from the dataBytes object
    [dataBytes getBytes:&dataArray length:dataLength * sizeof(uint16_t)];
    uint16_t rawAmbientTemp = dataArray[SENSOR_DATA_INDEX_TEMP_AMBIENT];
    
    // get the ambient temperature
    double ambientTempC = ((double)rawAmbientTemp)/128;
    double ambientTempF = [self fahrenheitFromCelsius:ambientTempC];
    NSLog(@"*** AMBIENT TEMPERATURE SENSOR (C/F): 2.0%f/2.0%f", ambientTempC, ambientTempF);
    
    // Use the Ambient Temperature reading for our label
    NSInteger temp = (NSInteger)ambientTempF;
    [self setBackgroundImageForTemperature:temp];
    self.captionLabel.hidden = NO;
    self.temperatureLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:81];
    self.temperatureLabel.text = [NSString stringWithFormat:@" %ld°", (long)temp];
}

- (void)drawCircle {
    self.circleView.hidden = NO;
    CAShapeLayer *circleLayer = [CAShapeLayer layer];
    [circleLayer setPath:[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, self.circleView.bounds.size.width, self.circleView.bounds.size.height)] CGPath]];
    [[self.circleView layer] addSublayer:circleLayer];
    [circleLayer setLineWidth:2];
    [circleLayer setStrokeColor:[UIColor whiteColor].CGColor];
    [circleLayer setFillColor:[UIColor clearColor].CGColor];
    circleDrawn = YES;
}

- (void)setBackgroundImageForTemperature:(NSInteger)temperature {
    NSInteger temperatureToTens = 10;
    if (temperature > 19) {
        if (temperature > 99) {
            temperatureToTens = 100;
        } else {
            temperatureToTens = 10 * floor( temperature / 10 + 0.5 );
        }
    }
    
    if (temperatureToTens != self.lastTemperatureTens) {
        NSString *temperatureFilename = [NSString stringWithFormat:@"temp-%ld", temperatureToTens];
        NSLog(@"*** BACKGROUND FILENAME: %@", temperatureFilename);
        
        // fade out old, fade in new.
        UIImageView *visibleBackground = self.backgroundImageViews[self.visibleBackgroundIndex];
        UIImageView *invisibleBackground = self.backgroundImageViews[self.invisibleBackgroundIndex];
        invisibleBackground.image = [UIImage imageNamed:temperatureFilename];
        invisibleBackground.alpha = 0;
        [self.view bringSubviewToFront:invisibleBackground];
        [self.view bringSubviewToFront:self.controlContainerView];
        
        [UIView animateWithDuration:0.5 animations:^{
            // "crossfade" the two images
            invisibleBackground.alpha = 1;
        } completion:^(BOOL finished) {
            // rotate the indices: if it was 1 before now it's 0 and vice versa...
            visibleBackground.alpha = 0;
            NSInteger indexTemp = self.visibleBackgroundIndex;
            self.visibleBackgroundIndex = self.invisibleBackgroundIndex;
            self.invisibleBackgroundIndex = indexTemp;
            NSLog(@"**** NEW INDICES - visible: %ld - invisible: %ld", (long)self.visibleBackgroundIndex, (long)self.invisibleBackgroundIndex);
        }];
    }
}

- (void)displayHumidity:(NSData *)dataBytes {
    // get the data's length - divide by two since we're creating an array that holds 16-bit (two-byte) values...
    // NOTE: Technically, because we have the documentation (http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Humidity_Sensor_2)
    //       we already know that it's 2 16-bit integers, but this feels a bit more flexible.
    NSUInteger dataLength = dataBytes.length / 2;
    
    // create an array to contain the 16-bit values
    uint16_t dataArray[dataLength];
    for (int i = 0; i < dataLength; i++) {
        dataArray[i] = 0;
    }
    
    // extract the data from the dataBytes object
    [dataBytes getBytes:&dataArray length:dataLength * sizeof(uint16_t)];
    uint16_t rawHumidity = dataArray[SENSOR_DATA_INDEX_HUMIDITY];
    double calculatedHumidity = calculateRelativeHumidity(rawHumidity);
    NSLog(@"*** HUMIDITY SENSOR: %f%%", calculatedHumidity);
    self.humidityLabel.text = [NSString stringWithFormat:@"Humidity: %.01f%%", calculatedHumidity];

//    // Humidity sensor also retrieves a temperature, which we don't use.
//    // However, for instructional purposes, here's how to get at it to compare to the ambient sensor:
//    uint16_t rawHumidityTemp = dataArray[SENSOR_DATA_INDEX_HUMIDITY_TEMP];
//    double calculatedTemperature = calcHumidityTemperature(rawHumidityTemp);
//    NSLog(@"*** HUMIDITY SENSOR - TEMPERATURE: %f", calculatedTemperature);
}


#pragma mark - Utility Methods

- (double)fahrenheitFromCelsius:(double)celsius {
    double fahrenheit = (celsius * 1.8) + 32;
    return fahrenheit;
}


/* Conversion algorithm, temperature */
double calcHumidityTemperature(uint16_t rawT) {
    double v;
    //-- calculate temperature [deg C] --
    v = -46.85 + 175.72/65536 *(double)(uint16_t)rawT;
    return v;
}

/*  Conversion algorithm, humidity */
double calculateRelativeHumidity(uint16_t rawH) {
    double v;
    rawH &= ~0x0003; // clear bits [1..0] (status bits)
    //-- calculate relative humidity [%RH] --
    v = -6.0 + 125.0/65536 * (double)rawH; // RH= -6 + 125 * SRH/2^16
    return v;
}


#pragma mark - CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    BOOL showAlert = YES;
    NSString *state = @"";
    switch ([central state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"This device does not support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"This app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth on this device is currently powered off.";
            break;
        case CBCentralManagerStateResetting:
            state = @"The BLE Manager is resetting; a state update is pending.";
            break;
        case CBCentralManagerStatePoweredOn:
            showAlert = NO;
            state = @"Bluetooth LE is turned on and ready for communication.";
            NSLog(@"%@", state);
            self.keepScanning = YES;
            [NSTimer scheduledTimerWithTimeInterval:TIMER_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
            break;
        case CBCentralManagerStateUnknown:
            state = @"The state of the BLE Manager is unknown.";
            break;
        default:
            state = @"The state of the BLE Manager is unknown.";
    }
    
    if (showAlert) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Central Manager State" message:state preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [ac addAction:okAction];
        [self presentViewController:ac animated:YES completion:nil];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
    NSString *peripheralName = [advertisementData objectForKey:@"kCBAdvDataLocalName"];
    NSLog(@"NEXT PERIPHERAL: %@ (%@)", peripheralName, peripheral.identifier.UUIDString);
    if (peripheralName) {
        if ([peripheralName isEqualToString:SENSOR_TAG_NAME]) {
            self.keepScanning = NO;
            
            // save a reference to the sensor tag
            self.sensorTag = peripheral;
            self.sensorTag.delegate = self;
            
            // Request a connection to the peripheral
            [self.centralManager connectPeripheral:self.sensorTag options:nil];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"**** SUCCESSFULLY CONNECTED TO SENSOR TAG!!!");
    self.temperatureLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:56];
    self.temperatureLabel.text = @"Connected";

    // Now that we've successfully connected to the SensorTag, let's discover the services.
    // - NOTE:  we pass nil here to request ALL services be discovered.
    //          If there was a subset of services we were interested in, we could pass the UUIDs here.
    //          Doing so saves batter life and saves time.
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"**** CONNECTION FAILED!!!");
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"**** DISCONNECTED FROM SENSOR TAG!!!");
}


#pragma mark - CBPeripheralDelegate methods

// When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service);
        if (([service.UUID isEqual:[CBUUID UUIDWithString:UUID_TEMPERATURE_SERVICE]]) ||
            ([service.UUID isEqual:[CBUUID UUIDWithString:UUID_HUMIDITY_SERVICE]])) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        uint8_t enableValue = 1;
        NSData *enableBytes = [NSData dataWithBytes:&enableValue length:sizeof(uint8_t)];
        
        // Temperature
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_TEMPERATURE_DATA]]) {
            // Enable Temperature Sensor notification
            [self.sensorTag setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_TEMPERATURE_CONFIG]]) {
            // Enable Temperature Sensor
            [self.sensorTag writeValue:enableBytes forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
        
        
        // Humidity
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_HUMIDITY_DATA]]) {
            // Enable Humidity Sensor notification
            [self.sensorTag setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_HUMIDITY_CONFIG]]) {
            // Enable Humidity Sensor
            [self.sensorTag writeValue:enableBytes forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state: %@", [error localizedDescription]);
    } else {
        // extract the data from the characteristic's value property and display the value based on the characteristic type
        NSData *dataBytes = characteristic.value;
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_TEMPERATURE_DATA]]) {
            [self displayTemperature:dataBytes];
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:UUID_HUMIDITY_DATA]]) {
            [self displayHumidity:dataBytes];
        }
    }
}

@end

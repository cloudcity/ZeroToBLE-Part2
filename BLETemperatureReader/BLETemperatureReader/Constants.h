//
//  Constants.h
//  BLETemperatureReader
//
//  Created by Evan Stone on 8/7/15.
//  Copyright (c) 2015 Cloud City. All rights reserved.
//

#ifndef BLETemperatureReader_Constants_h
#define BLETemperatureReader_Constants_h

//------------------------------------------------------------------------
// Information about Texas Instruments SensorTag UUIDs can be found at:
// http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Sensors
//------------------------------------------------------------------------
// Per the TI documentation:
//  The TI Base 128-bit UUID is: F0000000-0451-4000-B000-000000000000.
//
//  All sensor services use 128-bit UUIDs, but for practical reasons only
//  the 16-bit part is listed in this document.
//
//  It is embedded in the 128-bit UUID as shown by example below.
//
//          Base 128-bit UUID:  F0000000-0451-4000-B000-000000000000
//          "0xAA01" maps as:   F000AA01-0451-4000-B000-000000000000
//                                  ^--^
//------------------------------------------------------------------------

// Temp UUIDs
#define UUID_TEMPERATURE_SERVICE @"F000AA00-0451-4000-B000-000000000000"
#define UUID_TEMPERATURE_DATA    @"F000AA01-0451-4000-B000-000000000000"
#define UUID_TEMPERATURE_CONFIG  @"F000AA02-0451-4000-B000-000000000000"

// Humidity
#define UUID_HUMIDITY_SERVICE @"F000AA20-0451-4000-B000-000000000000"
#define UUID_HUMIDITY_DATA    @"F000AA21-0451-4000-B000-000000000000"
#define UUID_HUMIDITY_CONFIG  @"F000AA22-0451-4000-B000-000000000000"



#endif

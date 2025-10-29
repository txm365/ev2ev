#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <WebServer.h>
#include <EEPROM.h>
#include <Wire.h>
#include <INA226_WE.h>

// Configuration
#define LED_PIN 2
#define TEMP_PIN 32
#define EEPROM_SIZE 512

// INA226 I2C Configuration
#define INA226_ADDRESS 0x40        // Default I2C address (can be 0x40-0x4F)
#define INA226_ENABLED_ADDR 200    // EEPROM address for INA226 enable flag

// BLE Configuration
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Web Server Configuration
String deviceID = String(ESP.getEfuseMac(),HEX);
String deviceName ="EV: ["+ deviceID + "]";

const char* ssid = deviceName.c_str();
const char* password = deviceID.c_str();
const char* device_id = ssid;
WebServer server(80);

BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// INA226 Instance
INA226_WE ina226(INA226_ADDRESS);
bool ina226Enabled = true;  // Enabled by default!
bool ina226Available = false;
float shuntResistor = 0.100;  // R100 = 0.100Ω (100mΩ) shunt resistor
float maxCurrent = 0.82;      // Maximum current with R100: ~0.82A (81.92mV / 0.1Ω)
float currentOffset = 0.0;    // Current calibration offset (for zero adjustment)

// Vehicle Profile Configuration
enum VehicleType { CAR, EBIKE, SCOOTER, CHARGING_STATION, VEHICLE_12V, VEHICLE_7V, CUSTOM };
VehicleType currentVehicleProfile = EBIKE;

struct VehicleProfile {
    const char* name;
    char brand[32];
    char model[32];
    float nominalVoltage;
    float maxPower;
    float batteryCapacity;
    float efficiency;
    float maxTemp;
    float chargeRate;
};

VehicleProfile profiles[] = {
    {"Electric Car", "Tesla", "Model 3", 400.0, 150.0, 75.0, 180.0, 45.0, 0.0},
    {"E-Bike", "Specialized", "Turbo Vado", 48.0, 0.5, 1.0, 20.0, 40.0, 0.0},
    {"Scooter", "Xiaomi", "Mi Electric Scooter", 60.0, 3.0, 2.5, 45.0, 50.0, 0.0},
    {"Charger", "ChargePoint", "CT4000", 400.0, 0.0, 0.0, 0.0, 60.0, 50.0},
    {"12V Vehicle", "Generic", "12V System", 12.0, 0.3, 0.1, 50.0, 40.0, 0.0},  // 12V: Car accessories, small systems (12V, 10Ah = 0.12kWh)
    {"7.2V Vehicle", "Generic", "7.2V System", 7.2, 0.05, 0.036, 100.0, 35.0, 0.0},  // 7.2V: RC batteries, power tools (7.2V, 5Ah = 0.036kWh)
    {"Custom", "", "", 48.0, 1.0, 2.0, 30.0, 50.0, 0.0}
};

struct EnergyData {
    float voltage;
    float current;
    float power;
    float temperature;
    float batteryLevel;
    float remainingRange;
};

EnergyData energyData = {0};
float currentCharge = profiles[currentVehicleProfile].batteryCapacity;

// SOC calculation variables
float totalChargeAh = 0;  // Total charge in Amp-hours
unsigned long lastSocUpdate = 0;
bool socInitialized = false;

bool useRandomData = false;
float manualVoltage = 0;
float manualCurrent = 0;
float manualTemperature = 0;
float manualBatteryLevel = 100;

unsigned long lastDataSentTime = 0;
unsigned long ledOnTime = 0;
bool ledBlinking = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        digitalWrite(LED_PIN, LOW);
    };
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        digitalWrite(LED_PIN, HIGH);
    }
};

void setProfile(VehicleType newProfile) {
    currentVehicleProfile = newProfile;
    currentCharge = profiles[currentVehicleProfile].batteryCapacity;
    manualBatteryLevel = 100;
    
    // Reset SOC when profile changes
    socInitialized = false;
    
    saveSettings();
}

VehicleType autoSelectProfile(float voltage) {
    // Auto-select profile based on voltage ranges
    // with tolerance for voltage sag/charge states
    
    if (voltage >= 360 && voltage <= 480) {
        return CAR;  // 400V nominal (360-480V range)
    } else if (voltage >= 54 && voltage <= 72) {
        return SCOOTER;  // 60V nominal (54-72V range)
    } else if (voltage >= 38 && voltage <= 58) {
        return EBIKE;  // 48V nominal (38-58V range)
    } else if (voltage >= 9.6 && voltage <= 15) {
        return VEHICLE_12V;  // 12V nominal (9.6-15V range)
    } else if (voltage >= 5.8 && voltage <= 9.5) {
        return VEHICLE_7V;  // 7.2V nominal (5.8-9.5V range)
    } else {
        // If voltage doesn't match any profile, stay with current
        return currentVehicleProfile;
    }
}

void checkAndAutoSelectProfile() {
    static bool autoSelected = false;
    
    // Only auto-select once on startup after getting first voltage reading
    if (!autoSelected && energyData.voltage > 0.5) {  // Valid voltage threshold
        VehicleType detectedProfile = autoSelectProfile(energyData.voltage);
        
        if (detectedProfile != currentVehicleProfile) {
            Serial.println("\n╔═══════════════════════════════════════╗");
            Serial.println("║   Auto-Profile Selection              ║");
            Serial.println("╚═══════════════════════════════════════╝");
            Serial.print("Detected voltage: ");
            Serial.print(energyData.voltage, 2);
            Serial.println("V");
            Serial.print("Previous profile: ");
            Serial.println(profiles[currentVehicleProfile].name);
            Serial.print("Detected profile: ");
            Serial.println(profiles[detectedProfile].name);
            Serial.println("→ Auto-switching...");
            
            currentVehicleProfile = detectedProfile;
            currentCharge = profiles[currentVehicleProfile].batteryCapacity;
            socInitialized = false;  // Reset SOC for new profile
            saveSettings();
            
            Serial.print("✓ Active profile: ");
            Serial.println(profiles[currentVehicleProfile].name);
            Serial.println();
        } else {
            Serial.println("\n[Auto-Select] Profile matches voltage");
            Serial.print("Voltage: ");
            Serial.print(energyData.voltage, 2);
            Serial.print("V → ");
            Serial.println(profiles[currentVehicleProfile].name);
        }
        
        autoSelected = true;
    }
}

void initINA226() {
    Serial.println("Initializing INA226 (I2C)...");
    
    Wire.begin();
    
    // Scan for INA226 in address range 0x40 to 0x4F
    Serial.println("\n╔════════════════════════════════════════╗");
    Serial.println("║       I2C Scanner - INA226             ║");
    Serial.println("╚════════════════════════════════════════╝");
    Serial.println("Scanning address range: 0x40 - 0x4F\n");
    
    byte foundAddress = 0;
    int devicesFound = 0;
    
    for (byte address = 0x40; address <= 0x4F; address++) {
        Wire.beginTransmission(address);
        byte error = Wire.endTransmission();
        
        if (error == 0) {
            Serial.print("  [FOUND] Device at 0x");
            if (address < 16) Serial.print("0");
            Serial.print(address, HEX);
            Serial.print(" ... ");
            
            // Try to initialize INA226 at this address
            INA226_WE testIna(address);
            if (testIna.init()) {
                Serial.println("INA226 CONFIRMED!");
                foundAddress = address;
                devicesFound++;
            } else {
                Serial.println("Not an INA226");
            }
        }
    }
    
    Serial.println("\n[Scan Complete]");
    Serial.print("INA226 devices found: ");
    Serial.println(devicesFound);
    
    if (devicesFound == 0) {
        Serial.println("\n[ERROR] No INA226 found!");
        Serial.println("\nTroubleshooting:");
        Serial.println("  1. Check wiring:");
        Serial.println("     SDA → GPIO 21 (ESP32)");
        Serial.println("     SCL → GPIO 22 (ESP32)");
        Serial.println("     VCC → 3.3V or 5V");
        Serial.println("     GND → GND");
        Serial.println("  2. Check I2C address jumpers");
        Serial.println("  3. Verify module power");
        ina226Available = false;
        return;
    }
    
    if (devicesFound > 1) {
        Serial.println("\n[WARNING] Multiple INA226 devices found!");
        Serial.print("Using first device at 0x");
        if (foundAddress < 16) Serial.print("0");
        Serial.println(foundAddress, HEX);
    }
    
    Serial.println("\n[Initializing INA226]");
    Serial.print("Selected address: 0x");
    if (foundAddress < 16) Serial.print("0");
    Serial.println(foundAddress, HEX);
    
    // Re-initialize INA226 object with found address
    ina226 = INA226_WE(foundAddress);
    
    if (ina226.init()) {
        ina226Available = true;
        
        // Set shunt resistor value and max current
        ina226.setResistorRange(shuntResistor, maxCurrent);
        
        // Set averaging for noise reduction
        ina226.setAverage(INA226_AVERAGE_16);
        
        // Set conversion times
        ina226.setConversionTime(INA226_CONV_TIME_1100);
        
        // Set mode to continuous measurement
        ina226.setMeasureMode(INA226_CONTINUOUS);
        
        Serial.println("\n✓ INA226 initialized successfully!");
        Serial.print("  Address: 0x");
        if (foundAddress < 16) Serial.print("0");
        Serial.println(foundAddress, HEX);
        Serial.print("  Shunt Resistor: ");
        Serial.print(shuntResistor, 4);
        Serial.println(" Ohm");
        Serial.print("  Max Current: ");
        Serial.print(maxCurrent, 3);
        Serial.println(" A");
        Serial.println();
    } else {
        ina226Available = false;
        Serial.println("\n[ERROR] INA226 initialization failed!");
        Serial.println("Device found but cannot initialize.");
    }
}

void readINA226Data() {
    if (!ina226Enabled || !ina226Available) {
        return;
    }
    
    // Debug output every 5 seconds
    static unsigned long lastDebug = 0;
    if (millis() - lastDebug > 5000) {
        Serial.println("[INA226] Reading hardware data...");
        lastDebug = millis();
    }
    
    // Read bus voltage
    energyData.voltage = ina226.getBusVoltage_V();
    
    // Read current (bidirectional) and apply calibration offset
    float rawCurrent = ina226.getCurrent_mA() / 1000.0;  // Convert mA to A
    energyData.current = rawCurrent - currentOffset;
    
    // Calculate power from voltage and calibrated current
    energyData.power = (energyData.voltage * energyData.current) / 1000.0;  // Convert W to kW
    
    // INA226 doesn't have temperature sensor - estimate based on current
    energyData.temperature = 25.0 + (abs(energyData.current) * 10.0);
    
    // Calculate real SOC using current integration (Coulomb counting)
    unsigned long currentTime = millis();
    const VehicleProfile& profile = profiles[currentVehicleProfile];
    
    // Safety checks
    if (profile.batteryCapacity <= 0 || profile.nominalVoltage <= 0) {
        Serial.println("[SOC] ERROR: Invalid battery capacity or voltage in profile!");
        energyData.batteryLevel = 0;
        energyData.remainingRange = 0;
        return;
    }
    
    if (!socInitialized) {
        // Initialize SOC calculation
        
        // Try to estimate initial SOC from voltage (rough estimation)
        float minVoltage = profile.nominalVoltage * 0.75;  // ~0% charged (conservative)
        float maxVoltage = profile.nominalVoltage * 1.15;  // ~100% charged (conservative)
        float voltageRange = maxVoltage - minVoltage;
        
        float estimatedSOC = 50.0;  // Default to 50% if can't estimate
        
        if (voltageRange > 0 && energyData.voltage > 0) {
            estimatedSOC = ((energyData.voltage - minVoltage) / voltageRange) * 100.0;
            estimatedSOC = constrain(estimatedSOC, 0, 100);
        }
        
        energyData.batteryLevel = estimatedSOC;
        
        // Convert SOC to charge in Ah
        float batteryCapacityAh = (profile.batteryCapacity * 1000.0) / profile.nominalVoltage;  // kWh to Ah
        totalChargeAh = (estimatedSOC / 100.0) * batteryCapacityAh;
        
        lastSocUpdate = currentTime;
        socInitialized = true;
        
        Serial.println("\n[SOC] Initialized from voltage");
        Serial.print("Battery: ");
        Serial.print(profile.nominalVoltage, 1);
        Serial.print("V, ");
        Serial.print(profile.batteryCapacity, 2);
        Serial.print("kWh (");
        Serial.print(batteryCapacityAh, 2);
        Serial.println(" Ah)");
        Serial.print("Voltage: ");
        Serial.print(energyData.voltage, 2);
        Serial.print("V (");
        Serial.print(minVoltage, 1);
        Serial.print("-");
        Serial.print(maxVoltage, 1);
        Serial.println("V range)");
        Serial.print("Estimated SOC: ");
        Serial.print(energyData.batteryLevel, 1);
        Serial.print("% (");
        Serial.print(totalChargeAh, 2);
        Serial.println(" Ah)");
    } else {
        // Update SOC using current integration
        float deltaTime = (currentTime - lastSocUpdate) / 1000.0;  // Convert to seconds
        lastSocUpdate = currentTime;
        
        // Integrate current over time to get charge change
        // Positive current = discharging (subtract), Negative current = charging (add)
        float chargeChange = -energyData.current * (deltaTime / 3600.0);  // Convert seconds to hours
        totalChargeAh += chargeChange;
        
        // Calculate battery capacity in Ah
        float batteryCapacityAh = (profile.batteryCapacity * 1000.0) / profile.nominalVoltage;  // kWh to Ah
        
        // Constrain total charge
        totalChargeAh = constrain(totalChargeAh, 0, batteryCapacityAh);
        
        // Calculate SOC percentage
        if (batteryCapacityAh > 0) {
            energyData.batteryLevel = (totalChargeAh / batteryCapacityAh) * 100.0;
            energyData.batteryLevel = constrain(energyData.batteryLevel, 0, 100);
        } else {
            energyData.batteryLevel = 0;
        }
    }
    
    // Update charge in kWh for other calculations
    currentCharge = (totalChargeAh * profile.nominalVoltage) / 1000.0;  // Ah to kWh
    currentCharge = constrain(currentCharge, 0, profile.batteryCapacity);
    
    // Calculate remaining range
    if (profile.efficiency > 0 && currentCharge > 0) {
        energyData.remainingRange = (currentCharge * 1000) / profile.efficiency;
    } else {
        energyData.remainingRange = 0;
    }
}

void updateSensorData() {
    const VehicleProfile& profile = profiles[currentVehicleProfile];
    
    if (ina226Enabled && ina226Available) {
        readINA226Data();
        return;
    }
    
    if (useRandomData) {
        energyData.voltage = profile.nominalVoltage * (0.9 + random(0, 200)/1000.0);
        
        if(profile.name == "Charger") {
            energyData.current = -profile.chargeRate * 1000 / energyData.voltage;
        } else {
            energyData.current = (random(-1000, 1000)/1000.0) * (profile.maxPower * 1000 / profile.nominalVoltage);
        }
        
        energyData.power = (energyData.voltage * energyData.current) / 1000.0;
        
        float deltaTime = 1.0 / 3600;
        currentCharge -= energyData.power * deltaTime;
        currentCharge = constrain(currentCharge, 0, profile.batteryCapacity);
        energyData.batteryLevel = (currentCharge / profile.batteryCapacity) * 100.0;
        
        energyData.temperature = constrain(
            random(profile.maxTemp * 10 - 500, profile.maxTemp * 10 + 500) / 10.0,
            20.0, 
            profile.maxTemp
        );
    } else {
        energyData.voltage = manualVoltage;
        energyData.current = manualCurrent;
        energyData.power = (energyData.voltage * energyData.current) / 1000.0;
        energyData.temperature = manualTemperature;
        energyData.batteryLevel = manualBatteryLevel;
        currentCharge = (manualBatteryLevel / 100.0) * profile.batteryCapacity;
    }
    
    if(profile.efficiency > 0) {
        energyData.remainingRange = (currentCharge * 1000) / profile.efficiency;
    } else {
        energyData.remainingRange = 0;
    }
}

void setupBLE() {
    BLEDevice::init(device_id);
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    BLEService *pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID,
                        BLECharacteristic::PROPERTY_READ |
                        BLECharacteristic::PROPERTY_NOTIFY |
                        BLECharacteristic::PROPERTY_WRITE
                      );
    pCharacteristic->addDescriptor(new BLE2902());
    pService->start();
    BLEDevice::startAdvertising();
}

void handleUpdateValue() {
    if (server.hasArg("name") && server.hasArg("value")) {
        String name = server.arg("name");
        float value = server.arg("value").toFloat();
        
        if (name == "voltage") manualVoltage = value;
        else if (name == "current") manualCurrent = value;
        else if (name == "temperature") manualTemperature = value;
        else if (name == "batteryLevel") manualBatteryLevel = value;
        
        saveSettings();
    }
    server.send(200, "text/plain", "OK");
}

void handleRoot() {
    String html = "<!DOCTYPE html><html><head>";
    html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
    html += "<style>";
    html += "body{font-family:Arial;margin:20px;background:#f0f0f0}";
    html += "h1,h2{color:#333}";
    html += "form{background:white;padding:20px;border-radius:8px;margin:10px 0}";
    html += "label{display:block;margin:10px 0 5px 0;font-weight:bold}";
    html += "input[type='range']{width:80%}";
    html += "input[type='number']{width:100px;margin-left:10px}";
    html += "input[type='text']{width:100%;padding:5px}";
    html += "select,button{padding:10px;margin:5px 0}";
    html += "button{background:#4CAF50;color:white;border:none;cursor:pointer;border-radius:4px;font-size:14px;font-weight:bold}";
    html += "button:hover{background:#45a049;transform:translateY(-1px);box-shadow:0 2px 5px rgba(0,0,0,0.2)}";
    html += "button:active{transform:translateY(0);box-shadow:0 1px 3px rgba(0,0,0,0.2)}";
    html += ".toggle-btn{min-width:150px;padding:12px 20px;transition:all 0.3s ease}";
    html += ".toggle-btn.enabled{background:#4CAF50}";
    html += ".toggle-btn.enabled:hover{background:#45a049}";
    html += ".toggle-btn.disabled{background:#f44336}";
    html += ".toggle-btn.disabled:hover{background:#da190b}";
    html += ".value-display{color:#2196F3;font-weight:bold}";
    html += ".status{padding:10px;margin:10px 0;border-radius:4px}";
    html += ".status.enabled{background:#4CAF50;color:white}";
    html += ".status.disabled{background:#f44336;color:white}";
    html += ".status.not-detected{background:#FF9800;color:white}";
    html += ".info-box{background:#E3F2FD;padding:15px;border-radius:8px;margin:10px 0;border-left:4px solid #2196F3}";
    html += ".live-data{background:#fff;padding:15px;border-radius:8px;margin:10px 0;border:2px solid #4CAF50}";
    html += ".live-indicator{display:inline-block;width:10px;height:10px;background:#4CAF50;border-radius:50%;margin-right:5px;animation:pulse 2s infinite}";
    html += "@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.3}}";
    html += "</style>";
    html += "<script>";
    html += "function updateValue(name,value){fetch('/updateValue?name='+name+'&value='+value)}";
    html += "function refreshData(){fetch('/getData').then(r=>r.json()).then(d=>{";
    html += "document.getElementById('liveV').innerText=d.V;";
    html += "document.getElementById('liveI').innerText=d.I;";
    // Power and unit come from server now
    html += "document.getElementById('liveP').innerText=d.P;";
    html += "document.getElementById('livePUnit').innerText=d.P_unit;";
    html += "document.getElementById('liveT').innerText=d.T;";
    html += "document.getElementById('liveSOC').innerText=d.SOC;";
    html += "document.getElementById('liveRange').innerText=d.Range;";
    html += "var dir='';";
    html += "if(d.I>0.01)dir='[Discharging]';";
    html += "else if(d.I<-0.01)dir='[Charging]';";
    html += "else dir='[Idle]';";
    html += "document.getElementById('liveDir').innerText=dir;";
    html += "}).catch(e=>console.log(e))}";
    html += "setInterval(refreshData,1000);";
    html += "window.onload=refreshData;";
    html += "</script>";
    html += "</head><body>";
    
    html += "<h1>EV2EV Vehicle Simulator</h1>";
    
    // INA226 Status
    html += "<h2>INA226 Power Monitor (I2C)</h2>";
    html += "<div class='status " + String(ina226Available ? (ina226Enabled ? "enabled" : "disabled") : "not-detected") + "'>";
    html += "<strong>Status:</strong> ";
    if (!ina226Available) {
        html += "Not Detected - Check I2C wiring";
    } else if (ina226Enabled) {
        html += "✓ Enabled (Reading Real Hardware)";
    } else {
        html += "○ Disabled (Using Simulation)";
    }
    html += "</div>";
    
    // Module Info
    html += "<div class='info-box'>";
    html += "<strong>Module Info:</strong><br>";
    html += "Chip: INA226 (16-bit ADC)<br>";
    html += "Interface: I2C<br>";
    html += "Address: 0x" + String(INA226_ADDRESS, HEX) + "<br>";
    html += "Shunt: R100 (" + String(shuntResistor, 3) + " Ohm)<br>";
    html += "Max Current: " + String(maxCurrent, 3) + "A<br>";
    html += "Bidirectional: Yes<br>";
    html += "Max Voltage: 36V";
    html += "</div>";
    
    // Enable/Disable
    if (ina226Available) {
        html += "<form action='/toggleINA226' method='POST' style='text-align:center;'>";
        html += "<button type='submit' class='toggle-btn " + String(ina226Enabled ? "enabled" : "disabled") + "'>";
        html += String(ina226Enabled ? "Disable INA226" : "Enable INA226") + "</button>";
        html += "</form>";
    }
    
    // Configuration
    html += "<form action='/setINA226Config' method='POST'>";
    html += "<label>Shunt Resistor (Ω):</label>";
    html += "<input type='number' name='shunt' step='0.001' value='" + String(shuntResistor, 4) + "'>";
    html += "<span style='font-size:0.9em;color:#666'> (R100 = 0.100Ω)</span><br>";
    html += "<label>Max Current (A):</label>";
    html += "<input type='number' name='maxCurrent' step='0.01' value='" + String(maxCurrent, 3) + "'>";
    html += "<span style='font-size:0.9em;color:#666'> (Recommended: 0.82A with R100)</span><br>";
    html += "<label>Current Offset (A):</label>";
    html += "<input type='number' name='currentOffset' step='0.001' value='" + String(currentOffset, 3) + "'>";
    html += "<span style='font-size:0.9em;color:#666'> (Zero calibration)</span><br>";
    html += "<button type='submit'>Update Configuration</button>";
    html += "</form>";
    
    // Calibration Helper
    if (ina226Available) {
        html += "<div class='info-box'>";
        html += "<strong>📏 Current Calibration:</strong><br>";
        html += "1. Disconnect all loads (no current flow)<br>";
        html += "2. Note the current reading above<br>";
        html += "3. Enter that value as 'Current Offset'<br>";
        html += "4. Click 'Update Configuration'<br>";
        html += "Example: If it reads 0.015A with no load, enter 0.015<br>";
        html += "<form action='/autoCalibrate' method='POST' style='margin-top:10px'>";
        html += "<button type='submit'>Auto-Calibrate Now</button>";
        html += "<span style='font-size:0.9em;color:#666;margin-left:10px'>(Disconnect loads first!)</span>";
        html += "</form>";
        html += "</div>";
        
        html += "<div class='info-box' style='border-left:4px solid #FF9800'>";
        html += "<strong>SOC Management:</strong><br>";
        html += "Current voltage: " + String(energyData.voltage, 2) + "V<br>";
        html += "Current SOC: " + String(energyData.batteryLevel, 1) + "%<br><br>";
        html += "<form action='/setSOC' method='POST'>";
        html += "<label>Set SOC manually (%):</label>";
        html += "<input type='number' name='soc' min='0' max='100' step='0.1' value='50' style='width:80px'>";
        html += "<button type='submit'>Set SOC</button><br>";
        html += "<small>Use this if SOC shows 'nan' or is incorrect</small>";
        html += "</form>";
        html += "<form action='/resetSOC' method='POST' style='margin-top:10px'>";
        html += "<button type='submit'>Reset SOC (Re-estimate from voltage)</button>";
        html += "</form>";
        html += "</div>";
    }
    
    // Vehicle Profile
    html += "<h2>Vehicle Profile</h2>";
    html += "<form action='/setProfile' method='POST'>";
    html += "<label>Select Profile:</label>";
    html += "<select name='profile'>";
    html += "<option value='0'" + String(currentVehicleProfile == CAR ? " selected" : "") + ">Electric Car</option>";
    html += "<option value='1'" + String(currentVehicleProfile == EBIKE ? " selected" : "") + ">E-Bike</option>";
    html += "<option value='2'" + String(currentVehicleProfile == SCOOTER ? " selected" : "") + ">Scooter</option>";
    html += "<option value='3'" + String(currentVehicleProfile == CHARGING_STATION ? " selected" : "") + ">Charging Station</option>";
    html += "<option value='4'" + String(currentVehicleProfile == VEHICLE_12V ? " selected" : "") + ">12V Vehicle</option>";
    html += "<option value='5'" + String(currentVehicleProfile == VEHICLE_7V ? " selected" : "") + ">7.2V Vehicle</option>";
    html += "<option value='6'" + String(currentVehicleProfile == CUSTOM ? " selected" : "") + ">Custom</option>";
    html += "</select>";
    html += "<button type='submit'>Set Profile</button>";
    html += "</form>";
    
    // Current Vehicle
    html += "<h2>Current Vehicle</h2>";
    html += "<p><strong>Brand:</strong> " + String(profiles[currentVehicleProfile].brand) + "</p>";
    html += "<p><strong>Model:</strong> " + String(profiles[currentVehicleProfile].model) + "</p>";
    html += "<p><strong>Type:</strong> " + String(profiles[currentVehicleProfile].name) + "</p>";
    
    // Live Data Display (auto-refreshing)
    html += "<h2><span class='live-indicator'></span>Live Readings</h2>";
    html += "<div class='live-data'>";
    html += "<p><strong>Voltage:</strong> <span id='liveV'>" + String(energyData.voltage, 2) + "</span> V</p>";
    html += "<p><strong>Current:</strong> <span id='liveI'>" + String(energyData.current, 3) + "</span> A <span id='liveDir'>";
    if (energyData.current > 0.01) html += "[Discharging]";
    else if (energyData.current < -0.01) html += "[Charging]";
    else html += "[Idle]";
    html += "</span></p>";
    
    // Smart power display with unit
    float powerInWatts = energyData.power * 1000.0;
    if (abs(powerInWatts) >= 1000.0) {
        html += "<p><strong>Power:</strong> <span id='liveP'>" + String(energyData.power, 4) + "</span> <span id='livePUnit'>kW</span></p>";
    } else {
        html += "<p><strong>Power:</strong> <span id='liveP'>" + String(powerInWatts, 2) + "</span> <span id='livePUnit'>W</span></p>";
    }
    
    html += "<p><strong>Temperature:</strong> <span id='liveT'>" + String(energyData.temperature, 1) + "</span> C</p>";
    html += "<p><strong>Battery:</strong> <span id='liveSOC'>" + String(energyData.batteryLevel, 1) + "</span> %</p>";
    html += "<p><strong>Range:</strong> <span id='liveRange'>" + String(energyData.remainingRange, 1) + "</span> km</p>";
    html += "<p style='font-size:0.9em;color:#666;margin-top:10px'>Auto-refresh every 1 second</p>";
    html += "</div>";
    
    // Data Source Selection
    html += "<h2>Data Source</h2>";
    html += "<form action='/setDataSource' method='POST'>";
    html += "<label>Select Data Source:</label><br>";
    html += "<input type='radio' id='ina226' name='dataSource' value='ina226'" + String((ina226Enabled && ina226Available) ? " checked" : "") + ">";
    html += "<label for='ina226' style='display:inline;font-weight:normal;margin-left:5px'>INA226 Hardware" + String(ina226Available ? "" : " (Not Available)") + "</label><br>";
    html += "<input type='radio' id='random' name='dataSource' value='random'" + String((!ina226Enabled && useRandomData) ? " checked" : "") + ">";
    html += "<label for='random' style='display:inline;font-weight:normal;margin-left:5px'>Random Simulation</label><br>";
    html += "<input type='radio' id='manual' name='dataSource' value='manual'" + String((!ina226Enabled && !useRandomData) ? " checked" : "") + ">";
    html += "<label for='manual' style='display:inline;font-weight:normal;margin-left:5px'>Manual Control</label><br>";
    html += "<button type='submit'>Apply Data Source</button>";
    html += "</form>";
    
    // Manual Control Sliders (only shown when manual control is selected)
    if (!ina226Enabled && !useRandomData) {
            html += "<div>";
            html += "<label>Voltage (V): <span class='value-display'>" + String(manualVoltage) + "</span></label>";
            html += "<input type='range' id='voltage' min='0' max='" + String(profiles[currentVehicleProfile].nominalVoltage * 1.5) + 
                    "' step='0.1' value='" + String(manualVoltage) + "' oninput='updateValue(\"voltage\",this.value);document.querySelector(\".value-display\").innerHTML=this.value'><br>";
            
            html += "<label>Current (A): <span class='value-display'>" + String(manualCurrent) + "</span></label>";
            float maxCurrentSlider = (profiles[currentVehicleProfile].maxPower * 1000) / profiles[currentVehicleProfile].nominalVoltage;
            html += "<input type='range' id='current' min='" + String(-maxCurrentSlider * 1.5) + "' max='" + String(maxCurrentSlider * 1.5) + 
                    "' step='0.1' value='" + String(manualCurrent) + "' oninput='updateValue(\"current\",this.value);document.querySelectorAll(\".value-display\")[1].innerHTML=this.value'><br>";
            
            html += "<label>Temperature (C): <span class='value-display'>" + String(manualTemperature) + "</span></label>";
            html += "<input type='range' id='temperature' min='0' max='" + String(profiles[currentVehicleProfile].maxTemp) + 
                    "' step='0.1' value='" + String(manualTemperature) + "' oninput='updateValue(\"temperature\",this.value);document.querySelectorAll(\".value-display\")[2].innerHTML=this.value'><br>";
            
            html += "<label>Battery Level (%): <span class='value-display'>" + String(manualBatteryLevel) + "</span></label>";
            html += "<input type='range' id='batteryLevel' min='0' max='100' step='0.1' value='" + String(manualBatteryLevel) + 
                    "' oninput='updateValue(\"batteryLevel\",this.value);document.querySelectorAll(\".value-display\")[3].innerHTML=this.value'><br>";
            html += "</div>";
    }
    
    // Custom Profile
    if (currentVehicleProfile == CUSTOM) {
        html += "<h2>Custom Profile Settings</h2>";
        html += "<form action='/setCustomProfile' method='POST'>";
        html += "<label>Brand:</label><input type='text' name='brand' value='" + String(profiles[CUSTOM].brand) + "'><br>";
        html += "<label>Model:</label><input type='text' name='model' value='" + String(profiles[CUSTOM].model) + "'><br>";
        html += "<label>Nominal Voltage (V):</label><input type='number' name='voltage' step='0.1' value='" + String(profiles[CUSTOM].nominalVoltage) + "'><br>";
        html += "<label>Max Power (kW):</label><input type='number' name='power' step='0.1' value='" + String(profiles[CUSTOM].maxPower) + "'><br>";
        html += "<label>Battery Capacity (kWh):</label><input type='number' name='capacity' step='0.1' value='" + String(profiles[CUSTOM].batteryCapacity) + "'><br>";
        html += "<label>Efficiency (Wh/km):</label><input type='number' name='efficiency' step='0.1' value='" + String(profiles[CUSTOM].efficiency) + "'><br>";
        html += "<label>Max Temperature (C):</label><input type='number' name='maxTemp' step='0.1' value='" + String(profiles[CUSTOM].maxTemp) + "'><br>";
        html += "<label>Charge Rate (kW):</label><input type='number' name='chargeRate' step='0.1' value='" + String(profiles[CUSTOM].chargeRate) + "'><br>";
        html += "<button type='submit'>Save Custom Profile</button>";
        html += "</form>";
    }
    
    html += "</body></html>";
    server.send(200, "text/html", html);
}

void handleSetProfile() {
    if (server.hasArg("profile")) {
        setProfile((VehicleType)server.arg("profile").toInt());
    }
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleSetDataSource() {
    if (server.hasArg("dataSource")) {
        String source = server.arg("dataSource");
        if (source == "ina226" && ina226Available) {
            ina226Enabled = true;
            useRandomData = false;
            Serial.println("Data Source: INA226 Hardware");
        } else if (source == "random") {
            ina226Enabled = false;
            useRandomData = true;
            Serial.println("Data Source: Random Simulation");
        } else if (source == "manual") {
            ina226Enabled = false;
            useRandomData = false;
            Serial.println("Data Source: Manual Control");
        }
        saveSettings();
    }
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleToggleINA226() {
    if (ina226Available) {
        ina226Enabled = !ina226Enabled;
        saveSettings();
    }
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleSetINA226Config() {
    bool updated = false;
    
    if (server.hasArg("shunt")) {
        float newShunt = server.arg("shunt").toFloat();
        if (newShunt > 0 && newShunt < 1.0) {
            shuntResistor = newShunt;
            updated = true;
        }
    }
    
    if (server.hasArg("maxCurrent")) {
        float newMax = server.arg("maxCurrent").toFloat();
        if (newMax > 0 && newMax < 100) {
            maxCurrent = newMax;
            updated = true;
        }
    }
    
    if (server.hasArg("currentOffset")) {
        currentOffset = server.arg("currentOffset").toFloat();
        Serial.print("[Calibration] Current offset set to: ");
        Serial.print(currentOffset, 3);
        Serial.println(" A");
        updated = true;
    }
    
    if (updated && ina226Available) {
        ina226.setResistorRange(shuntResistor, maxCurrent);
        saveSettings();
    }
    
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleAutoCalibrate() {
    if (ina226Available && ina226Enabled) {
        // Read current multiple times and average
        float sum = 0;
        int samples = 10;
        
        for (int i = 0; i < samples; i++) {
            sum += ina226.getCurrent_mA() / 1000.0;
            delay(50);
        }
        
        currentOffset = sum / samples;
        
        Serial.println("\n[Auto-Calibration] Complete!");
        Serial.print("Current offset: ");
        Serial.print(currentOffset, 3);
        Serial.println(" A");
        Serial.println("This value will be subtracted from all readings.");
        
        saveSettings();
    }
    
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleSetSOC() {
    if (server.hasArg("soc")) {
        float newSOC = server.arg("soc").toFloat();
        newSOC = constrain(newSOC, 0, 100);
        
        energyData.batteryLevel = newSOC;
        
        // Convert SOC to charge in Ah
        const VehicleProfile& profile = profiles[currentVehicleProfile];
        float batteryCapacityAh = (profile.batteryCapacity * 1000.0) / profile.nominalVoltage;
        totalChargeAh = (newSOC / 100.0) * batteryCapacityAh;
        
        socInitialized = true;
        
        Serial.println("\n[SOC] Manually set");
        Serial.print("SOC: ");
        Serial.print(newSOC, 1);
        Serial.print("% (");
        Serial.print(totalChargeAh, 2);
        Serial.println(" Ah)");
    }
    
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleResetSOC() {
    socInitialized = false;
    Serial.println("\n[SOC] Reset - will re-initialize on next reading");
    
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleSetCustomProfile() {
    if (server.hasArg("brand")) {
        strncpy(profiles[CUSTOM].brand, server.arg("brand").c_str(), sizeof(profiles[CUSTOM].brand) - 1);
        profiles[CUSTOM].brand[sizeof(profiles[CUSTOM].brand) - 1] = '\0';
    }
    if (server.hasArg("model")) {
        strncpy(profiles[CUSTOM].model, server.arg("model").c_str(), sizeof(profiles[CUSTOM].model) - 1);
        profiles[CUSTOM].model[sizeof(profiles[CUSTOM].model) - 1] = '\0';
    }
    if (server.hasArg("voltage")) profiles[CUSTOM].nominalVoltage = server.arg("voltage").toFloat();
    if (server.hasArg("power")) profiles[CUSTOM].maxPower = server.arg("power").toFloat();
    if (server.hasArg("capacity")) profiles[CUSTOM].batteryCapacity = server.arg("capacity").toFloat();
    if (server.hasArg("efficiency")) profiles[CUSTOM].efficiency = server.arg("efficiency").toFloat();
    if (server.hasArg("maxTemp")) profiles[CUSTOM].maxTemp = server.arg("maxTemp").toFloat();
    if (server.hasArg("chargeRate")) profiles[CUSTOM].chargeRate = server.arg("chargeRate").toFloat();
    
    saveSettings();
    server.sendHeader("Location", "/");
    server.send(303);
}

void handleGetData() {
    // Update sensor data on every request
    updateSensorData();
    
    // Create JSON response
    DynamicJsonDocument doc(256);
    doc["V"] = round(energyData.voltage * 100) / 100.0;
    doc["I"] = round(energyData.current * 1000) / 1000.0;
    
    // Send power with smart units matching Serial Monitor display
    float powerInWatts = energyData.power * 1000.0;
    if (abs(powerInWatts) >= 1000.0) {
        doc["P"] = round(energyData.power * 10000) / 10000.0;
        doc["P_unit"] = "kW";
    } else {
        doc["P"] = round(powerInWatts * 100) / 100.0;
        doc["P_unit"] = "W";
    }
    
    doc["T"] = round(energyData.temperature * 10) / 10.0;
    doc["SOC"] = round(energyData.batteryLevel * 10) / 10.0;
    doc["Range"] = round(energyData.remainingRange * 10) / 10.0;
    
    String jsonString;
    serializeJson(doc, jsonString);
    
    server.send(200, "application/json", jsonString);
}

void setupWebServer() {
    WiFi.softAP(ssid, password);
    server.on("/", handleRoot);
    server.on("/setProfile", HTTP_POST, handleSetProfile);
    server.on("/setDataSource", HTTP_POST, handleSetDataSource);
    server.on("/toggleINA226", HTTP_POST, handleToggleINA226);
    server.on("/setINA226Config", HTTP_POST, handleSetINA226Config);
    server.on("/autoCalibrate", HTTP_POST, handleAutoCalibrate);
    server.on("/setSOC", HTTP_POST, handleSetSOC);
    server.on("/resetSOC", HTTP_POST, handleResetSOC);
    server.on("/updateValue", handleUpdateValue);
    server.on("/setCustomProfile", HTTP_POST, handleSetCustomProfile);
    server.on("/getData", handleGetData);  // New endpoint for live data
    server.begin();
    
    Serial.println("Web server started");
    Serial.print("WiFi: ");
    Serial.println(ssid);
    Serial.print("URL: http://");
    Serial.println(WiFi.softAPIP());
}

void loadSettings() {
    EEPROM.begin(EEPROM_SIZE);
    currentVehicleProfile = (VehicleType)EEPROM.read(0);
    if (currentVehicleProfile > CUSTOM) currentVehicleProfile = EBIKE;
    useRandomData = EEPROM.read(1);
    EEPROM.get(2, manualVoltage);
    EEPROM.get(6, manualCurrent);
    EEPROM.get(10, manualTemperature);
    EEPROM.get(14, manualBatteryLevel);
    EEPROM.get(18, profiles[CUSTOM].nominalVoltage);
    EEPROM.get(22, profiles[CUSTOM].maxPower);
    EEPROM.get(26, profiles[CUSTOM].batteryCapacity);
    EEPROM.get(30, profiles[CUSTOM].efficiency);
    EEPROM.get(34, profiles[CUSTOM].maxTemp);
    EEPROM.get(38, profiles[CUSTOM].chargeRate);
    
    for (int i = 0; i < sizeof(profiles[CUSTOM].brand); i++) {
        profiles[CUSTOM].brand[i] = EEPROM.read(42 + i);
        if (profiles[CUSTOM].brand[i] == '\0') break;
    }
    profiles[CUSTOM].brand[sizeof(profiles[CUSTOM].brand) - 1] = '\0';
    
    for (int i = 0; i < sizeof(profiles[CUSTOM].model); i++) {
        profiles[CUSTOM].model[i] = EEPROM.read(42 + sizeof(profiles[CUSTOM].brand) + i);
        if (profiles[CUSTOM].model[i] == '\0') break;
    }
    profiles[CUSTOM].model[sizeof(profiles[CUSTOM].model) - 1] = '\0';
    
    ina226Enabled = EEPROM.read(INA226_ENABLED_ADDR);
    EEPROM.get(INA226_ENABLED_ADDR + 1, shuntResistor);
    EEPROM.get(INA226_ENABLED_ADDR + 5, maxCurrent);
    EEPROM.get(INA226_ENABLED_ADDR + 9, currentOffset);
    EEPROM.end();
    
    if (manualVoltage == 0) manualVoltage = profiles[currentVehicleProfile].nominalVoltage;
    if (manualTemperature == 0) manualTemperature = profiles[currentVehicleProfile].maxTemp / 2;
    if (shuntResistor == 0 || shuntResistor > 1.0) shuntResistor = 0.100;
    if (maxCurrent == 0 || maxCurrent > 100) maxCurrent = 0.82;
}

void saveSettings() {
    EEPROM.begin(EEPROM_SIZE);
    EEPROM.write(0, currentVehicleProfile);
    EEPROM.write(1, useRandomData);
    EEPROM.put(2, manualVoltage);
    EEPROM.put(6, manualCurrent);
    EEPROM.put(10, manualTemperature);
    EEPROM.put(14, manualBatteryLevel);
    EEPROM.put(18, profiles[CUSTOM].nominalVoltage);
    EEPROM.put(22, profiles[CUSTOM].maxPower);
    EEPROM.put(26, profiles[CUSTOM].batteryCapacity);
    EEPROM.put(30, profiles[CUSTOM].efficiency);
    EEPROM.put(34, profiles[CUSTOM].maxTemp);
    EEPROM.put(38, profiles[CUSTOM].chargeRate);
    
    for (int i = 0; i < sizeof(profiles[CUSTOM].brand); i++) {
        EEPROM.write(42 + i, profiles[CUSTOM].brand[i]);
        if (profiles[CUSTOM].brand[i] == '\0') break;
    }
    
    for (int i = 0; i < sizeof(profiles[CUSTOM].model); i++) {
        EEPROM.write(42 + sizeof(profiles[CUSTOM].brand) + i, profiles[CUSTOM].model[i]);
        if (profiles[CUSTOM].model[i] == '\0') break;
    }
    
    EEPROM.write(INA226_ENABLED_ADDR, ina226Enabled);
    EEPROM.put(INA226_ENABLED_ADDR + 1, shuntResistor);
    EEPROM.put(INA226_ENABLED_ADDR + 5, maxCurrent);
    EEPROM.put(INA226_ENABLED_ADDR + 9, currentOffset);
    EEPROM.commit();
    EEPROM.end();
}

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("\n\n╔═══════════════════════════════════════╗");
    Serial.println("║   EV2EV Simulator - INA226 Edition   ║");
    Serial.println("╚═══════════════════════════════════════╝\n");
    
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);
    Serial.println("✓ LED initialized");
    
    Serial.println("\n--- Loading Settings ---");
    loadSettings();
    Serial.print("Profile: ");
    Serial.println(profiles[currentVehicleProfile].name);
    Serial.print("Data Source: ");
    if (ina226Enabled) Serial.println("INA226 (if available)");
    else if (useRandomData) Serial.println("Random");
    else Serial.println("Manual");
    
    Serial.println("\n--- Initializing INA226 ---");
    initINA226();
    
    Serial.println("\n--- Starting BLE ---");
    setupBLE();
    Serial.print("BLE Device: ");
    Serial.println(device_id);
    
    Serial.println("\n--- Starting WiFi AP ---");
    setupWebServer();
    
    Serial.println("\n╔═══════════════════════════════════════╗");
    Serial.println("║         System Ready!                 ║");
    Serial.println("╚═══════════════════════════════════════╝");
    Serial.println("\nStatus Summary:");
    Serial.print("• INA226: ");
    if (ina226Available) {
        Serial.print("✓ Available");
        if (ina226Enabled) Serial.println(" & ENABLED");
        else Serial.println(" (disabled)");
    } else {
        Serial.println("✗ Not detected");
    }
    Serial.print("• WiFi AP: ");
    Serial.println(ssid);
    Serial.print("• Web Interface: http://");
    Serial.println(WiFi.softAPIP());
    Serial.print("• BLE: ");
    Serial.println(device_id);
    Serial.println("\n--- Starting Data Stream ---\n");
}

void loop() {
    unsigned long currentMillis = millis();

    // Update sensor data every second regardless of BLE connection
    if(currentMillis - lastDataSentTime >= 1000) {
        lastDataSentTime = currentMillis;
        
        // Show data source being used
        static unsigned long lastSourcePrint = 0;
        if (currentMillis - lastSourcePrint > 10000) {  // Print every 10 seconds
            Serial.print("\n[Source: ");
            if (ina226Enabled && ina226Available) Serial.print("INA226 Hardware");
            else if (useRandomData) Serial.print("Random Simulation");
            else Serial.print("Manual Control");
            Serial.println("]");
            lastSourcePrint = currentMillis;
        }
        
        updateSensorData();
        
        // Auto-select profile based on voltage (once on startup)
        checkAndAutoSelectProfile();

        // Print formatted output with smart power units
        Serial.print("V: ");
        Serial.print(energyData.voltage, 2);
        Serial.print("V | I: ");
        Serial.print(energyData.current, 3);
        Serial.print("A ");
        if (energyData.current > 0.01) Serial.print("⚡");
        else if (energyData.current < -0.01) Serial.print("🔋");
        else Serial.print("⚬");
        Serial.print(" | P: ");
        
        // Display power in W or kW based on value
        float powerInWatts = energyData.power * 1000.0;
        if (abs(powerInWatts) >= 1000.0) {
            Serial.print(energyData.power, 4);
            Serial.print("kW");
        } else {
            Serial.print(powerInWatts, 2);
            Serial.print("W");
        }
        
        Serial.print(" | T: ");
        Serial.print(energyData.temperature, 1);
        Serial.print("°C | SOC: ");
        Serial.print(energyData.batteryLevel, 1);
        Serial.println("%");

        // Send via BLE if connected
        if(deviceConnected) {
            DynamicJsonDocument doc(256);
            doc["profile"] = profiles[currentVehicleProfile].name;
            doc["brand"] = profiles[currentVehicleProfile].brand;
            doc["model"] = profiles[currentVehicleProfile].model;
            doc["V"] = round(energyData.voltage * 10) / 10.0;
            doc["I"] = round(energyData.current * 1000) / 1000.0;
            
            // Send power with smart units
            float powerInWatts = energyData.power * 1000.0;
            if (abs(powerInWatts) >= 1000.0) {
                doc["P"] = round(energyData.power * 10000) / 10000.0;
                doc["P_unit"] = "kW";
            } else {
                doc["P"] = round(powerInWatts * 100) / 100.0;
                doc["P_unit"] = "W";
            }
            
            doc["T"] = round(energyData.temperature * 10) / 10.0;
            doc["SOC"] = round(energyData.batteryLevel * 10) / 10.0;
            doc["Range"] = round(energyData.remainingRange * 10) / 10.0;
            doc["INA226"] = ina226Enabled && ina226Available;

            String jsonString;
            serializeJson(doc, jsonString);
            
            pCharacteristic->setValue(jsonString.c_str());
            pCharacteristic->notify();
        }

        digitalWrite(LED_PIN, HIGH);
        ledOnTime = currentMillis;
        ledBlinking = true;
    }

    if(ledBlinking && (currentMillis - ledOnTime >= 200)) {
        digitalWrite(LED_PIN, LOW);
        ledBlinking = false;
    }

    if(!deviceConnected && oldDeviceConnected) {
        delay(500);
        BLEDevice::startAdvertising();
        Serial.println("\n[BLE] Device disconnected, restarting advertising...");
        oldDeviceConnected = deviceConnected;
    }
    if(deviceConnected && !oldDeviceConnected) {
        Serial.println("\n[BLE] Device connected!");
        oldDeviceConnected = deviceConnected;
    }
    
    server.handleClient();
}

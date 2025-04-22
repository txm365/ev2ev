#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <WebServer.h>
#include <EEPROM.h>

// Configuration
#define LED_PIN 2
#define TEMP_PIN 32
#define EEPROM_SIZE 512

// BLE Configuration
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Web Server Configuration
const char* ssid = "EV:> [BX 22 NX GP]";
const char* password = "bx22nxgp";
const char* device_id = ssid;
WebServer server(80);

BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Vehicle Profile Configuration
enum VehicleType { CAR, EBIKE, SCOOTER, CHARGING_STATION, CUSTOM };
VehicleType currentVehicleProfile = EBIKE;

struct VehicleProfile {
    const char* name;
    char brand[32];           // Vehicle brand name
    char model[32];           // Vehicle model name
    float nominalVoltage;     // V
    float maxPower;           // kW
    float batteryCapacity;    // kWh
    float efficiency;         // Wh/km
    float maxTemp;            // °C
    float chargeRate;         // kW (for charging stations)
};

VehicleProfile profiles[] = {
    // Car (EV)
    {
        "Electric Car",
        "Tesla", "Model 3",
        400.0,     // 400V system
        150.0,      // 150kW max power
        75.0,       // 75kWh battery
        180.0,      // 180 Wh/km
        45.0,       // Max temp
        0.0         // Not a charger
    },
    // E-bike
    {
        "E-Bike",
        "Specialized", "Turbo Vado",
        48.0,
        0.5,        // 500W motor
        1.0,        // 1kWh battery
        20.0,       // 20 Wh/km
        40.0,
        0.0
    },
    // Scooter
    {
        "Scooter",
        "Xiaomi", "Mi Electric Scooter",
        60.0,
        3.0,        // 3kW motor
        2.5,        // 2.5kWh battery
        45.0,       // 45 Wh/km
        50.0,
        0.0
    },
    // Charging Station
    {
        "Charger",
        "ChargePoint", "CT4000",
        400.0,
        0.0,        // No battery
        0.0,
        0.0,
        60.0,
        50.0        // 50kW charge rate
    },
    // Custom Profile
    {
        "Custom",
        "", "",      // Empty brand/model for custom
        48.0,
        1.0,
        2.0,
        30.0,
        50.0,
        0.0
    }
};

struct EnergyData {
    float voltage;          // V
    float current;          // A
    float power;            // kW
    float temperature;      // °C
    float batteryLevel;     // %
    float remainingRange;   // km
};

EnergyData energyData = {0};
float currentCharge = profiles[currentVehicleProfile].batteryCapacity;  // Start full

// Web Interface Parameters
bool useRandomData = false;
float manualVoltage = 0;
float manualCurrent = 0;
float manualTemperature = 0;
float manualBatteryLevel = 100;

// Timing and LED control
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
    saveSettings();
}

void updateSensorData() {
    const VehicleProfile& profile = profiles[currentVehicleProfile];
    
    if (useRandomData) {
        // Simulate voltage with ±10% variation
        energyData.voltage = profile.nominalVoltage * (0.9 + random(0, 200)/1000.0);
        
        // Simulate current based on power requirements
        if(profile.name == "Charger") {
            energyData.current = -profile.chargeRate * 1000 / energyData.voltage;  // Charging current
        } else {
            energyData.current = (random(-1000, 1000)/1000.0) * (profile.maxPower * 1000 / profile.nominalVoltage);
        }
        
        // Calculate power (kW)
        energyData.power = (energyData.voltage * energyData.current) / 1000.0;
        
        // Update battery charge
        float deltaTime = 1.0 / 3600;  // 1 second in hours
        currentCharge -= energyData.power * deltaTime;
        
        // Clamp values
        currentCharge = constrain(currentCharge, 0, profile.batteryCapacity);
        
        // Calculate battery level
        energyData.batteryLevel = (currentCharge / profile.batteryCapacity) * 100.0;
        
        // Simulate temperature
        energyData.temperature = constrain(
            random(profile.maxTemp * 10 - 500, profile.maxTemp * 10 + 500) / 10.0,
            20.0, 
            profile.maxTemp
        );
    } else {
        // Use manual values
        energyData.voltage = manualVoltage;
        energyData.current = manualCurrent;
        energyData.power = (energyData.voltage * energyData.current) / 1000.0;
        energyData.temperature = manualTemperature;
        energyData.batteryLevel = manualBatteryLevel;
        currentCharge = (manualBatteryLevel / 100.0) * profile.batteryCapacity;
    }
    
    // Calculate remaining range
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
        
        if (name == "voltage") {
            manualVoltage = value;
        } else if (name == "current") {
            manualCurrent = value;
        } else if (name == "temperature") {
            manualTemperature = value;
        } else if (name == "batteryLevel") {
            manualBatteryLevel = value;
        }
        
        saveSettings();
        server.send(200, "text/plain", "OK");
    } else {
        server.send(400, "text/plain", "Bad Request");
    }
}

void setupWebServer() {
    WiFi.softAP(ssid, password);
    IPAddress IP = WiFi.softAPIP();
    Serial.print("AP IP address: ");
    Serial.println(IP);

    server.on("/", HTTP_GET, []() {
        String html = "<!DOCTYPE html><html><head><title>EV2EV Device</title>";
        html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
        html += "<style>";
        html += "body {font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5;}";
        html += ".container {background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);}";
        html += "h1 {color: #2c3e50;}";
        html += "label {display: block; margin-top: 15px; font-weight: bold;}";
        html += "input[type='range'] {width: 100%; margin: 10px 0;}";
        html += "input[type='number'] {width: 100px; padding: 5px;}";
        html += "button {background-color: #3498db; color: white; border: none; padding: 10px 15px; border-radius: 5px; cursor: pointer; margin-top: 15px;}";
        html += "button:hover {background-color: #2980b9;}";
        html += ".value-display {color: #27ae60; font-weight: bold;}";
        html += "</style>";
        html += "<script>";
        html += "function updateValue(name, value) {";
        html += "  fetch('/updateValue?name=' + name + '&value=' + value, {method: 'POST'});";
        html += "}";
        html += "</script>";
        html += "</head><body><div class='container'>";
        html += "<h1>EV2EV VEHICLE CONFIG</h1>";
        
        // Vehicle Profile Selection
        html += "<form action='/setProfile' method='POST'>";
        html += "<label>Vehicle Profile:</label>";
        html += "<select name='profile'>";
        html += "<option value='0'" + String(currentVehicleProfile == CAR ? " selected" : "") + ">Electric Car</option>";
        html += "<option value='1'" + String(currentVehicleProfile == EBIKE ? " selected" : "") + ">E-Bike</option>";
        html += "<option value='2'" + String(currentVehicleProfile == SCOOTER ? " selected" : "") + ">Scooter</option>";
        html += "<option value='3'" + String(currentVehicleProfile == CHARGING_STATION ? " selected" : "") + ">Charging Station</option>";
        html += "<option value='4'" + String(currentVehicleProfile == CUSTOM ? " selected" : "") + ">Custom</option>";
        html += "</select>";
        html += "<button type='submit'>Set Profile</button>";
        html += "</form>";
        
        // Current Vehicle Info
        html += "<h2>Current Vehicle</h2>";
        html += "<p><strong>Brand:</strong> " + String(profiles[currentVehicleProfile].brand) + "</p>";
        html += "<p><strong>Model:</strong> " + String(profiles[currentVehicleProfile].model) + "</p>";
        html += "<p><strong>Type:</strong> " + String(profiles[currentVehicleProfile].name) + "</p>";
        
        // Data Source Selection
        html += "<form action='/setDataSource' method='POST'>";
        html += "<label>Data Source:</label>";
        html += "<input type='radio' id='random' name='dataSource' value='random'" + String(useRandomData ? " checked" : "") + ">";
        html += "<label for='random' style='display: inline; font-weight: normal;'>Random Data</label><br>";
        html += "<input type='radio' id='manual' name='dataSource' value='manual'" + String(!useRandomData ? " checked" : "") + ">";
        html += "<label for='manual' style='display: inline; font-weight: normal;'>Manual Control</label><br>";
        html += "<button type='submit'>Set Data Source</button>";
        html += "</form>";
        
        // Manual Control Sliders (only shown when manual control is selected)
        if (!useRandomData) {
            html += "<div>";
            
            // Voltage
            html += "<label for='voltage'>Voltage (V): <span class='value-display'>" + String(manualVoltage) + "</span></label>";
            html += "<input type='range' id='voltage' name='voltage' min='0' max='" + String(profiles[currentVehicleProfile].nominalVoltage * 1.5) + 
                    "' step='0.1' value='" + String(manualVoltage) + "' oninput='document.querySelector(\"#voltageValue\").value=this.value; document.querySelector(\".value-display\").innerHTML=this.value; updateValue(\"voltage\", this.value)'>";
            html += "<input type='number' id='voltageValue' min='0' max='" + String(profiles[currentVehicleProfile].nominalVoltage * 1.5) + 
                    "' step='0.1' value='" + String(manualVoltage) + "' oninput='document.querySelector(\"#voltage\").value=this.value; document.querySelector(\".value-display\").innerHTML=this.value; updateValue(\"voltage\", this.value)'><br>";
            
            // Current
            html += "<label for='current'>Current (A): <span class='value-display'>" + String(manualCurrent) + "</span></label>";
            float maxCurrent = (profiles[currentVehicleProfile].maxPower * 1000) / profiles[currentVehicleProfile].nominalVoltage;
            html += "<input type='range' id='current' name='current' min='" + String(-maxCurrent * 1.5) + "' max='" + String(maxCurrent * 1.5) + 
                    "' step='0.1' value='" + String(manualCurrent) + "' oninput='document.querySelector(\"#currentValue\").value=this.value; document.querySelectorAll(\".value-display\")[1].innerHTML=this.value; updateValue(\"current\", this.value)'>";
            html += "<input type='number' id='currentValue' min='" + String(-maxCurrent * 1.5) + "' max='" + String(maxCurrent * 1.5) + 
                    "' step='0.1' value='" + String(manualCurrent) + "' oninput='document.querySelector(\"#current\").value=this.value; document.querySelectorAll(\".value-display\")[1].innerHTML=this.value; updateValue(\"current\", this.value)'><br>";
            
            // Temperature
            html += "<label for='temperature'>Temperature (°C): <span class='value-display'>" + String(manualTemperature) + "</span></label>";
            html += "<input type='range' id='temperature' name='temperature' min='0' max='" + String(profiles[currentVehicleProfile].maxTemp) + 
                    "' step='0.1' value='" + String(manualTemperature) + "' oninput='document.querySelector(\"#temperatureValue\").value=this.value; document.querySelectorAll(\".value-display\")[2].innerHTML=this.value; updateValue(\"temperature\", this.value)'>";
            html += "<input type='number' id='temperatureValue' min='0' max='" + String(profiles[currentVehicleProfile].maxTemp) + 
                    "' step='0.1' value='" + String(manualTemperature) + "' oninput='document.querySelector(\"#temperature\").value=this.value; document.querySelectorAll(\".value-display\")[2].innerHTML=this.value; updateValue(\"temperature\", this.value)'><br>";
            
            // Battery Level
            html += "<label for='batteryLevel'>Battery Level (%): <span class='value-display'>" + String(manualBatteryLevel) + "</span></label>";
            html += "<input type='range' id='batteryLevel' name='batteryLevel' min='0' max='100' step='0.1' value='" + String(manualBatteryLevel) + 
                    "' oninput='document.querySelector(\"#batteryLevelValue\").value=this.value; document.querySelectorAll(\".value-display\")[3].innerHTML=this.value; updateValue(\"batteryLevel\", this.value)'>";
            html += "<input type='number' id='batteryLevelValue' min='0' max='100' step='0.1' value='" + String(manualBatteryLevel) + 
                    "' oninput='document.querySelector(\"#batteryLevel\").value=this.value; document.querySelectorAll(\".value-display\")[3].innerHTML=this.value; updateValue(\"batteryLevel\", this.value)'><br>";
            
            html += "</div>";
        }
        
        // Custom Profile Configuration
        if (currentVehicleProfile == CUSTOM) {
            html += "<h2>Custom Profile Settings</h2>";
            html += "<form action='/setCustomProfile' method='POST'>";
            
            html += "<label for='vehicleBrand'>Brand:</label>";
            html += "<input type='text' id='vehicleBrand' name='vehicleBrand' value='" + String(profiles[CUSTOM].brand) + "'><br>";
            
            html += "<label for='vehicleModel'>Model:</label>";
            html += "<input type='text' id='vehicleModel' name='vehicleModel' value='" + String(profiles[CUSTOM].model) + "'><br>";
            
            html += "<label for='nominalVoltage'>Nominal Voltage (V):</label>";
            html += "<input type='number' id='nominalVoltage' name='nominalVoltage' step='0.1' value='" + String(profiles[CUSTOM].nominalVoltage) + "'><br>";
            
            html += "<label for='maxPower'>Max Power (kW):</label>";
            html += "<input type='number' id='maxPower' name='maxPower' step='0.1' value='" + String(profiles[CUSTOM].maxPower) + "'><br>";
            
            html += "<label for='batteryCapacity'>Battery Capacity (kWh):</label>";
            html += "<input type='number' id='batteryCapacity' name='batteryCapacity' step='0.1' value='" + String(profiles[CUSTOM].batteryCapacity) + "'><br>";
            
            html += "<label for='efficiency'>Efficiency (Wh/km):</label>";
            html += "<input type='number' id='efficiency' name='efficiency' step='0.1' value='" + String(profiles[CUSTOM].efficiency) + "'><br>";
            
            html += "<label for='maxTemp'>Max Temperature (°C):</label>";
            html += "<input type='number' id='maxTemp' name='maxTemp' step='0.1' value='" + String(profiles[CUSTOM].maxTemp) + "'><br>";
            
            html += "<label for='chargeRate'>Charge Rate (kW):</label>";
            html += "<input type='number' id='chargeRate' name='chargeRate' step='0.1' value='" + String(profiles[CUSTOM].chargeRate) + "'><br>";
            
            html += "<button type='submit'>Update Custom Profile</button>";
            html += "</form>";
        }
        
        html += "</div></body></html>";
        server.send(200, "text/html", html);
    });

    server.on("/setProfile", HTTP_POST, []() {
        if (server.hasArg("profile")) {
            int profile = server.arg("profile").toInt();
            setProfile(static_cast<VehicleType>(profile));
        }
        server.sendHeader("Location", "/");
        server.send(303);
    });

    server.on("/setDataSource", HTTP_POST, []() {
        if (server.hasArg("dataSource")) {
            useRandomData = (server.arg("dataSource") == "random");
            saveSettings();
        }
        server.sendHeader("Location", "/");
        server.send(303);
    });

    server.on("/updateValue", HTTP_POST, handleUpdateValue);

    server.on("/setCustomProfile", HTTP_POST, []() {
        if (server.hasArg("nominalVoltage")) profiles[CUSTOM].nominalVoltage = server.arg("nominalVoltage").toFloat();
        if (server.hasArg("maxPower")) profiles[CUSTOM].maxPower = server.arg("maxPower").toFloat();
        if (server.hasArg("batteryCapacity")) profiles[CUSTOM].batteryCapacity = server.arg("batteryCapacity").toFloat();
        if (server.hasArg("efficiency")) profiles[CUSTOM].efficiency = server.arg("efficiency").toFloat();
        if (server.hasArg("maxTemp")) profiles[CUSTOM].maxTemp = server.arg("maxTemp").toFloat();
        if (server.hasArg("chargeRate")) profiles[CUSTOM].chargeRate = server.arg("chargeRate").toFloat();
        
        // Save brand and model
        if (server.hasArg("vehicleBrand")) {
            strncpy(profiles[CUSTOM].brand, server.arg("vehicleBrand").c_str(), sizeof(profiles[CUSTOM].brand) - 1);
            profiles[CUSTOM].brand[sizeof(profiles[CUSTOM].brand) - 1] = '\0';
        }
        if (server.hasArg("vehicleModel")) {
            strncpy(profiles[CUSTOM].model, server.arg("vehicleModel").c_str(), sizeof(profiles[CUSTOM].model) - 1);
            profiles[CUSTOM].model[sizeof(profiles[CUSTOM].model) - 1] = '\0';
        }
        
        saveSettings();
        server.sendHeader("Location", "/");
        server.send(303);
    });

    server.begin();
}

void loadSettings() {
    EEPROM.begin(EEPROM_SIZE);
    
    // Read current profile
    currentVehicleProfile = static_cast<VehicleType>(EEPROM.read(0));
    if (currentVehicleProfile > CUSTOM) currentVehicleProfile = EBIKE;
    
    // Read data source
    useRandomData = EEPROM.read(1);
    
    // Read manual values
    EEPROM.get(2, manualVoltage);
    EEPROM.get(6, manualCurrent);
    EEPROM.get(10, manualTemperature);
    EEPROM.get(14, manualBatteryLevel);
    
    // Read custom profile
    EEPROM.get(18, profiles[CUSTOM].nominalVoltage);
    EEPROM.get(22, profiles[CUSTOM].maxPower);
    EEPROM.get(26, profiles[CUSTOM].batteryCapacity);
    EEPROM.get(30, profiles[CUSTOM].efficiency);
    EEPROM.get(34, profiles[CUSTOM].maxTemp);
    EEPROM.get(38, profiles[CUSTOM].chargeRate);
    
    // Read brand and model (starting at byte 42)
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
    
    EEPROM.end();
    
    // Initialize manual values if they're 0 (first run)
    if (manualVoltage == 0) manualVoltage = profiles[currentVehicleProfile].nominalVoltage;
    if (manualTemperature == 0) manualTemperature = profiles[currentVehicleProfile].maxTemp / 2;
}

void saveSettings() {
    EEPROM.begin(EEPROM_SIZE);
    
    // Save current profile
    EEPROM.write(0, currentVehicleProfile);
    
    // Save data source
    EEPROM.write(1, useRandomData);
    
    // Save manual values
    EEPROM.put(2, manualVoltage);
    EEPROM.put(6, manualCurrent);
    EEPROM.put(10, manualTemperature);
    EEPROM.put(14, manualBatteryLevel);
    
    // Save custom profile
    EEPROM.put(18, profiles[CUSTOM].nominalVoltage);
    EEPROM.put(22, profiles[CUSTOM].maxPower);
    EEPROM.put(26, profiles[CUSTOM].batteryCapacity);
    EEPROM.put(30, profiles[CUSTOM].efficiency);
    EEPROM.put(34, profiles[CUSTOM].maxTemp);
    EEPROM.put(38, profiles[CUSTOM].chargeRate);
    
    // Save brand and model (starting at byte 42)
    for (int i = 0; i < sizeof(profiles[CUSTOM].brand); i++) {
        EEPROM.write(42 + i, profiles[CUSTOM].brand[i]);
        if (profiles[CUSTOM].brand[i] == '\0') break;
    }
    
    for (int i = 0; i < sizeof(profiles[CUSTOM].model); i++) {
        EEPROM.write(42 + sizeof(profiles[CUSTOM].brand) + i, profiles[CUSTOM].model[i]);
        if (profiles[CUSTOM].model[i] == '\0') break;
    }
    
    EEPROM.commit();
    EEPROM.end();
}

void setup() {
    Serial.begin(115200);
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);
    
    loadSettings();
    setupBLE();
    setupWebServer();
}

void loop() {
    unsigned long currentMillis = millis();

    if(deviceConnected && (currentMillis - lastDataSentTime >= 1000)) {
        lastDataSentTime = currentMillis;
        updateSensorData();

        DynamicJsonDocument doc(256);
        doc["profile"] = profiles[currentVehicleProfile].name;
        doc["brand"] = profiles[currentVehicleProfile].brand;
        doc["model"] = profiles[currentVehicleProfile].model;
        doc["V"] = round(energyData.voltage * 10) / 10.0;
        doc["I"] = round(energyData.current * 10) / 10.0;
        doc["P"] = round(energyData.power * 10) / 10.0;
        doc["T"] = round(energyData.temperature * 10) / 10.0;
        doc["SOC"] = round(energyData.batteryLevel * 10) / 10.0;
        doc["Range"] = round(energyData.remainingRange * 10) / 10.0;

        String jsonString;
        serializeJson(doc, jsonString);
        
        pCharacteristic->setValue(jsonString.c_str());
        pCharacteristic->notify();
        Serial.println(jsonString);

        digitalWrite(LED_PIN, HIGH);
        ledOnTime = currentMillis;
        ledBlinking = true;
    }

    if(ledBlinking && (currentMillis - ledOnTime >= 200)) {
        digitalWrite(LED_PIN, LOW);
        ledBlinking = false;
    }

    // Handle BLE connection state
    if(!deviceConnected && oldDeviceConnected) {
        delay(500);
        BLEDevice::startAdvertising();
        oldDeviceConnected = deviceConnected;
    }
    if(deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }
    
    // Handle web server requests
    server.handleClient();
}
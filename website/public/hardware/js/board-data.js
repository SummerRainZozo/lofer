/* Parts, wires and breadboard nets shown on the board. */
window.LOFER_BOARD_DATA = {
 "comps": {
  "BAT": {
   "name": "LiPo 403450, protected, ≥2C",
   "kind": "Power source",
   "purpose": "Stores the energy for the whole rig. This cell has its own protection board, which cuts the load off if the battery is drained too far, so over-discharge is stopped in hardware even if the firmware misbehaves.",
   "notes": [
    "Rated for at least 2C (1.7 A). The heater, motor and ESP32 radio can peak together at about 1.4 A, and a weaker cell would sag the supply.",
    "Size 4.0 × 34 × 50 mm."
   ],
   "pins": {
    "+": "+ (red lead)",
    "-": "− (black lead)"
   },
   "holes": {}
  },
  "TP": {
   "name": "TP4056 USB-C charger",
   "kind": "Charger",
   "purpose": "Charges the battery from USB-C at up to 1 A and stays connected to the battery at all times, so charging works even when the power switch is off.",
   "notes": [
    "The B− pad is the single star-ground point. Two separate wires are soldered to it: the sensor and logic ground from the breadboard, and the DRV8833's heavy-current ground. Actuator current therefore never flows through the breadboard ground the ADC uses.",
    "Avoid charging while the heater runs: a load on the cell can stop the charger from detecting a full battery."
   ],
   "pins": {
    "B+": "B+ pad",
    "B-": "B− pad (star ground)"
   },
   "holes": {}
  },
  "SW": {
   "name": "SPDT slide switch",
   "kind": "Power switch",
   "purpose": "Turns the whole rig off. It sits after the charger, so the battery still charges with the switch off, and its output feeds both the 3.3 V regulator and the motor driver, so off really means off.",
   "notes": [
    "Rated ≥2 A, 6 V DC."
   ],
   "pins": {
    "IN": "Common (from battery)",
    "OUT": "Switched output"
   },
   "holes": {}
  },
  "REG": {
   "name": "TPS63001 buck-boost, 3.3 V",
   "kind": "Regulator",
   "purpose": "Makes the clean 3.3 V rail for the ESP32 and every sensor. A buck-boost converter keeps 3.3 V steady whether the battery is above or below 3.3 V, so it works over the battery's whole 3.0–4.2 V range.",
   "notes": [
    "Reaches ~800 mA from a low battery, enough for ESP32 radio peaks (~0.5 A) plus the sensors."
   ],
   "pins": {
    "VIN": "VIN",
    "GND": "GND",
    "VOUT": "VOUT 3.3 V"
   },
   "holes": {}
  },
  "ESP": {
   "name": "ESP32-S3-N16R8 DevKit",
   "kind": "Microcontroller",
   "purpose": "The brain of the rig. It reads every sensor, drives the heater and motor, talks to the phone over Bluetooth, and runs the firmware safety checks.",
   "notes": [
    "Watchdog: the heater may only run while the firmware keeps confirming it. Heater PWM is 0 and nSLEEP is low at boot and on every reset. A thermistor reading near either rail (open or shorted) is a fault and kills the heater.",
    "PWM: one LEDC channel each for heater (GPIO4) and motor (GPIO21), both at 20 kHz or more, outside the EMG band and above hearing. Motor duty is capped at about 70 %.",
    "EMG: GPIO1 samples the AD8232 at 1–2 kHz on ADC1. The firmware band-passes 20–450 Hz, rectifies and smooths it into an envelope, and only uses samples taken while the motor is off.",
    "Spare pins for later features: GPIO5 and GPIO47. Avoid GPIO0/3/45/46 (strapping), 19/20 (USB), 26–37 (flash/PSRAM) and 48 (RGB LED)."
   ],
   "pins": {
    "3V3": "3V3",
    "GND": "GND",
    "G1": "GPIO1",
    "G4": "GPIO4",
    "G6": "GPIO6",
    "G7": "GPIO7",
    "G8": "GPIO8",
    "G9": "GPIO9",
    "G10": "GPIO10",
    "G11": "GPIO11",
    "G12": "GPIO12",
    "G21": "GPIO21"
   },
   "holes": {}
  },
  "R1": {
   "name": "R1 · 100 kΩ (battery divider, top)",
   "kind": "Resistor",
   "purpose": "Top half of the battery-voltage divider. With R2 it halves the switched battery voltage so the ADS1115 can read it on A0: 4.2 V full reads 2.1 V, 3.0 V empty reads 1.5 V.",
   "notes": [
    "It hangs off the switched line, so the divider draws nothing when the rig is off.",
    "Firmware: low-battery warning below 3.3 V, clean shutdown at 3.0 V."
   ],
   "pins": {
    "1": "Leg 1",
    "2": "Leg 2"
   },
   "holes": {
    "1": "T1c",
    "2": "T3c"
   }
  },
  "R2": {
   "name": "R2 · 100 kΩ (battery divider, bottom)",
   "kind": "Resistor",
   "purpose": "Bottom half of the battery divider. It crosses the centre channel from the divider node to ground.",
   "notes": [],
   "pins": {
    "1": "Leg 1",
    "2": "Leg 2"
   },
   "holes": {
    "1": "T3e",
    "2": "B3f"
   }
  },
  "RNTC": {
   "name": "R3 · 10 kΩ (thermistor divider)",
   "kind": "Resistor",
   "purpose": "Fixed half of the thermistor divider. 3.3 V → 10 kΩ → node → thermistor → ground. The node reads about 1.65 V at 25 °C and about 1.08 V at 42 °C, so the voltage falls as the skin warms.",
   "notes": [
    "An open thermistor pulls the node to 3.3 V and a shorted one pulls it to 0 V. Both count as faults, and either one stops the heater.",
    "Use a 1 % metal-film resistor: its tolerance goes straight into the temperature reading."
   ],
   "pins": {
    "1": "Leg to 3.3 V",
    "2": "Leg to thermistor node"
   },
   "holes": {
    "1": "T6c",
    "2": "T8c"
   }
  },
  "J1": {
   "name": "J1 · flash link",
   "kind": "Removable jumper",
   "purpose": "Connects the regulator's 3.3 V rail to the ESP32's 3V3 pin. Pull it out before plugging in USB to flash or debug, and put it back afterwards.",
   "notes": [
    "With USB plugged in, the DevKit's own regulator also drives the 3V3 pin. Two supplies fighting over one pin can damage either of them.",
    "With J1 out and USB in, the ESP32 runs from USB and the sensors keep running from the TPS63001 if the power switch is on."
   ],
   "pins": {
    "1": "3.3 V rail side",
    "2": "ESP32 3V3 side"
   },
   "holes": {
    "1": "T6d",
    "2": "T9d"
   }
  },
  "C47": {
   "name": "C1 · 47 µF (ESP32 supply)",
   "kind": "Capacitor",
   "purpose": "Bulk capacitor right at the ESP32's supply. It covers the short current spikes of Bluetooth transmissions so they don't dip the 3.3 V rail.",
   "notes": [
    "Electrolytic: the striped leg is negative and goes to ground."
   ],
   "pins": {
    "+": "+ leg",
    "-": "− leg"
   },
   "holes": {
    "+": "T9e",
    "-": "B9f"
   }
  },
  "ADS": {
   "name": "ADS1115 16-bit ADC",
   "kind": "Analog-to-digital converter",
   "purpose": "Reads the slow analog signals precisely: battery voltage on A0 and skin temperature on A3. It tells the ESP32 when a new sample is ready through ALERT (GPIO6).",
   "notes": [
    "A1 and A2 are spare for future sensors. Fast EMG goes to the ESP32's own ADC instead, since this chip is built for precise, slow readings.",
    "ADDR to ground sets I²C address 0x48."
   ],
   "pins": {
    "VDD": "VDD",
    "GND": "GND",
    "SCL": "SCL",
    "SDA": "SDA",
    "ADDR": "ADDR",
    "ALERT": "ALERT",
    "A0": "A0",
    "A1": "A1 (free)",
    "A2": "A2 (free)",
    "A3": "A3"
   },
   "holes": {}
  },
  "CADS": {
   "name": "C2 · 100 nF (ADS1115 decoupling)",
   "kind": "Capacitor",
   "purpose": "Decoupling capacitor soldered across the ADS1115's VDD and GND pins. It supplies the chip's fast current spikes locally and keeps supply noise out of its readings.",
   "notes": [],
   "pins": {
    "1": "Lead to VDD",
    "2": "Lead to GND"
   },
   "holes": {}
  },
  "AHT": {
   "name": "AHT10 temperature & humidity",
   "kind": "Ambient sensor (bench only)",
   "purpose": "Measures room air temperature and humidity for context. It is an air sensor in a plastic housing, so it is never used for skin temperature or the heater cutoff.",
   "notes": [
    "Keep it on the bench board only. Inside a closed tile it would measure the electronics' own heat."
   ],
   "pins": {
    "VIN": "VIN",
    "GND": "GND",
    "SCL": "SCL",
    "SDA": "SDA"
   },
   "holes": {}
  },
  "CAHT": {
   "name": "C3 · 100 nF (AHT10 decoupling)",
   "kind": "Capacitor",
   "purpose": "Decoupling capacitor soldered across the AHT10's VIN and GND pins.",
   "notes": [],
   "pins": {
    "1": "Lead to VIN",
    "2": "Lead to GND"
   },
   "holes": {}
  },
  "DRV": {
   "name": "DRV8833 dual H-bridge",
   "kind": "Actuator driver",
   "purpose": "Switches battery current into the heater (bridge A) and the vibration motor (bridge B), under PWM control from the ESP32.",
   "notes": [
    "VM comes from the switched battery line, so the power switch turns it off.",
    "GND runs straight to the battery's star point, not through the breadboard.",
    "nSLEEP goes to GPIO11. Pulling it low turns off both bridges, a second heater kill that doesn't depend on the PWM pins. Its internal pull-down keeps the driver asleep while the ESP32 boots or resets.",
    "Each bridge uses one PWM input; the other input is tied to ground."
   ],
   "pins": {
    "VM": "VM",
    "GND": "GND",
    "EEP": "nSLEEP (EEP)",
    "IN1": "IN1",
    "IN2": "IN2",
    "IN3": "IN3",
    "IN4": "IN4",
    "OUT1": "OUT1",
    "OUT2": "OUT2",
    "OUT3": "OUT3",
    "OUT4": "OUT4"
   },
   "holes": {}
  },
  "C10": {
   "name": "C4 · 10 µF ceramic (VM)",
   "kind": "Capacitor",
   "purpose": "Ceramic capacitor right at the driver's VM and GND pins. It handles the fast current edges of the 20 kHz PWM.",
   "notes": [],
   "pins": {
    "1": "Lead to VM",
    "2": "Lead to GND"
   },
   "holes": {}
  },
  "C100": {
   "name": "C5 · 100 µF electrolytic (VM)",
   "kind": "Capacitor",
   "purpose": "Bulk capacitor on the driver supply. When the heater or motor switches on, it supplies the surge so the battery voltage doesn't dip as hard.",
   "notes": [],
   "pins": {
    "1": "+ lead to VM",
    "2": "− lead to GND"
   },
   "holes": {}
  },
  "TIE2": {
   "name": "IN2 tie to ground",
   "kind": "Jumper",
   "purpose": "A short jumper from IN2 to the module's own GND pin. With IN2 held low, the bridge runs in one direction from a single PWM signal on IN1.",
   "notes": [
    "A heater has no direction, and the motor never needs to reverse. One PWM channel per bridge also keeps GPIO5 and GPIO47 spare."
   ],
   "pins": {
    "p": "Jumper end"
   },
   "holes": {}
  },
  "TIE4": {
   "name": "IN4 tie to ground",
   "kind": "Jumper",
   "purpose": "A short jumper from IN4 to the module's own GND pin. With IN4 held low, the bridge runs in one direction from a single PWM signal on IN3.",
   "notes": [
    "A heater has no direction, and the motor never needs to reverse. One PWM channel per bridge also keeps GPIO5 and GPIO47 spare."
   ],
   "pins": {
    "p": "Jumper end"
   },
   "holes": {}
  },
  "TCO": {
   "name": "Thermal cutoff, 45 °C",
   "kind": "Hardware safety",
   "purpose": "A 45 °C normally-closed bimetal thermostat (KSD9700), wired in series with the heater's return. If the pad gets too hot it opens and cuts the heater current, whatever the firmware is doing.",
   "notes": [
    "Glue it to the back of the heater film next to the thermistor, with thermal epoxy or Kapton tape.",
    "It resets by itself once the pad cools."
   ],
   "pins": {
    "1": "Lead 1",
    "2": "Lead 2"
   },
   "holes": {}
  },
  "HTR": {
   "name": "Heater film 20 × 30 mm",
   "kind": "Actuator",
   "purpose": "Polyimide heating film that delivers soothing heat. It sits on the skin side of the tile between the two EMG electrodes. At battery voltage it gives about 1–1.5 W.",
   "notes": [
    "Driven by one 20 kHz+ PWM channel on IN1; IN2 is tied to ground.",
    "Two built-in safety controls: the firmware stops heating at 42 °C from the thermistor reading, and the thermal cutoff in its return lead opens at 45 °C.",
    "No charging while heating, and 1 mm of foam between the floor and the battery in the tile."
   ],
   "pins": {
    "+": "HEAT+ lead",
    "-": "HEAT− lead"
   },
   "holes": {}
  },
  "NTC": {
   "name": "10 kΩ NTC thermistor bead",
   "kind": "Safety sensor",
   "purpose": "A bare 10 kΩ thermistor bead glued to the back of the heater. It measures the temperature the skin is exposed to, and it drives the firmware's 42 °C heater cutoff.",
   "notes": [
    "A bare bead, not a module, so it sits flat against the heater.",
    "Runs on its own two wires to the breadboard.",
    "The back of the heater runs hotter than the skin, so the reading errs on the safe side.",
    "Calibrate it against a reference thermometer at about 25, 35 and 42 °C, then fit the Steinhart–Hart coefficients in firmware."
   ],
   "pins": {
    "A": "Lead A",
    "B": "Lead B"
   },
   "holes": {}
  },
  "MOT": {
   "name": "ERM coin vibration motor, 3 V",
   "kind": "Actuator",
   "purpose": "Coin vibration motor for deep-vibration massage and short haptic cues.",
   "notes": [
    "One 20 kHz+ PWM on IN3 with IN4 tied to ground, duty capped at about 70 %. At 4.2 V that averages ~2.9 V for a 3 V motor.",
    "No external diode is needed: the DRV8833's internal diodes handle the motor's switching spikes.",
    "EMG is only read while this motor is still, because its shaking moves the electrodes."
   ],
   "pins": {
    "+": "+ lead",
    "-": "− lead"
   },
   "holes": {}
  },
  "AD": {
   "name": "AD8232 EMG front-end (tuned for EMG)",
   "kind": "Muscle sensor amplifier",
   "purpose": "Amplifies the tiny muscle voltage picked up by the electrodes. Its raw output goes to the ESP32's own ADC, and its lead-off outputs tell the ESP32 whether the electrodes are touching skin.",
   "notes": [
    "Filter set for muscle signals, about 13–340 Hz: C4 and C6 = 100 nF, C3 = 1 nF, C1 = 220 pF, R9 = 470 kΩ.",
    "LO+ (GPIO7) and LO− (GPIO10) go high when an electrode loses the skin. This is the skin-contact check: no contact, no heat or vibration.",
    "SDN (GPIO12) puts it into shutdown to save power between sessions."
   ],
   "pins": {
    "3V3": "3.3V",
    "GND": "GND",
    "OUT": "OUTPUT",
    "LOP": "LO+",
    "LON": "LO−",
    "SDN": "SDN",
    "RA": "RA",
    "LA": "LA",
    "RL": "RL"
   },
   "holes": {}
  },
  "CAD": {
   "name": "C6 · 100 nF (AD8232 decoupling)",
   "kind": "Capacitor",
   "purpose": "Decoupling capacitor soldered across the AD8232's 3.3V and GND pins.",
   "notes": [],
   "pins": {
    "1": "Lead to 3.3V",
    "2": "Lead to GND"
   },
   "holes": {}
  },
  "EL": {
   "name": "Skin electrodes",
   "kind": "Sensor",
   "purpose": "Pick up the muscle's electrical activity. Two Ø8 mm discs sit 32 mm apart (±16 mm) on the tile's long axis, along the muscle fibres, with the heater between them. A third electrode on a ~15 cm lead goes on a bony spot as the reference.",
   "notes": [
    "Use stainless or silver-plated discs (copper is fine for the bench) with electrode gel or hydrogel dots.",
    "Keep the EMG cable twisted or shielded and away from the heater wires."
   ],
   "pins": {
    "A": "Electrode A (−X)",
    "B": "Electrode B (+X)",
    "REF": "Reference"
   },
   "holes": {}
  }
 },
 "wires": {
  "w_bat_p": {
   "a": [
    "BAT",
    "+"
   ],
   "b": [
    "TP",
    "B+"
   ],
   "label": "Battery + to charger",
   "note": "Soldered battery lead.",
   "kind": "wire",
   "color": "#B42318"
  },
  "w_bat_n": {
   "a": [
    "BAT",
    "-"
   ],
   "b": [
    "TP",
    "B-"
   ],
   "label": "Battery − to charger",
   "note": "Soldered battery lead.",
   "kind": "wire",
   "color": "#2C2C2A"
  },
  "w_sw_in": {
   "a": [
    "TP",
    "B+"
   ],
   "b": [
    "SW",
    "IN"
   ],
   "label": "Battery + to power switch",
   "note": "Unswitched battery. This is the only load wire on the B+ pad.",
   "kind": "wire",
   "color": "#B42318"
  },
  "w_sw_bb": {
   "a": [
    "SW",
    "OUT"
   ],
   "b": [
    "BB",
    "T1a"
   ],
   "label": "Switched battery to breadboard",
   "note": "Feeds the regulator and the battery divider.",
   "kind": "wire",
   "color": "#E24B4A"
  },
  "w_sw_drv": {
   "a": [
    "SW",
    "OUT"
   ],
   "b": [
    "DRV",
    "VM"
   ],
   "label": "Switched battery to DRV8833 VM",
   "note": "Takes the driver supply from the switch output, so turning the rig off also powers down the driver. Solder it to the switch lug; heater and motor current should not run through breadboard springs.",
   "kind": "wire",
   "color": "#E24B4A"
  },
  "w_reg_in": {
   "a": [
    "BB",
    "T1b"
   ],
   "b": [
    "REG",
    "VIN"
   ],
   "label": "Switched battery to regulator input",
   "note": "",
   "kind": "wire",
   "color": "#E24B4A"
  },
  "w_reg_gnd": {
   "a": [
    "REG",
    "GND"
   ],
   "b": [
    "BB",
    "B1h"
   ],
   "label": "Regulator ground",
   "note": "",
   "kind": "wire",
   "color": "#5F5E5A"
  },
  "w_reg_out": {
   "a": [
    "REG",
    "VOUT"
   ],
   "b": [
    "BB",
    "T5a"
   ],
   "label": "Regulator 3.3 V output to the rail",
   "note": "",
   "kind": "wire",
   "color": "#EF9F27"
  },
  "w_star": {
   "a": [
    "BB",
    "B1f"
   ],
   "b": [
    "TP",
    "B-"
   ],
   "label": "Sensor ground return to the star point",
   "note": "Carries only the small sensor and logic currents back to the battery's negative pad.",
   "kind": "wire",
   "color": "#2C2C2A"
  },
  "w_drv_gnd": {
   "a": [
    "DRV",
    "GND"
   ],
   "b": [
    "TP",
    "B-"
   ],
   "label": "DRV8833 ground straight to the star point",
   "note": "The heater and motor return current goes straight to the battery's negative pad on its own wire, so it never flows through the breadboard ground the ADC uses.",
   "kind": "wire",
   "color": "#2C2C2A"
  },
  "w_esp_3v3": {
   "a": [
    "BB",
    "T9a"
   ],
   "b": [
    "ESP",
    "3V3"
   ],
   "label": "3.3 V to the ESP32 (through J1)",
   "note": "Disconnected whenever J1 is pulled for flashing.",
   "kind": "wire",
   "color": "#EF9F27"
  },
  "w_esp_gnd": {
   "a": [
    "ESP",
    "GND"
   ],
   "b": [
    "BB",
    "B1g"
   ],
   "label": "ESP32 ground",
   "note": "",
   "kind": "wire",
   "color": "#5F5E5A"
  },
  "w_scl0": {
   "a": [
    "ESP",
    "G8"
   ],
   "b": [
    "BB",
    "T11a"
   ],
   "label": "I²C clock: ESP32-S3-N16R8",
   "note": "400 kHz bus. The modules' built-in pull-ups are enough for two devices.",
   "kind": "wire",
   "color": "#378ADD"
  },
  "w_scl1": {
   "a": [
    "ADS",
    "SCL"
   ],
   "b": [
    "BB",
    "T11b"
   ],
   "label": "I²C clock: ADS1115",
   "note": "400 kHz bus. The modules' built-in pull-ups are enough for two devices.",
   "kind": "wire",
   "color": "#378ADD"
  },
  "w_scl2": {
   "a": [
    "AHT",
    "SCL"
   ],
   "b": [
    "BB",
    "T11c"
   ],
   "label": "I²C clock: AHT10",
   "note": "400 kHz bus. The modules' built-in pull-ups are enough for two devices.",
   "kind": "wire",
   "color": "#378ADD"
  },
  "w_sda0": {
   "a": [
    "ESP",
    "G9"
   ],
   "b": [
    "BB",
    "T12a"
   ],
   "label": "I²C data: ESP32-S3-N16R8",
   "note": "",
   "kind": "wire",
   "color": "#1D9E75"
  },
  "w_sda1": {
   "a": [
    "ADS",
    "SDA"
   ],
   "b": [
    "BB",
    "T12b"
   ],
   "label": "I²C data: ADS1115",
   "note": "",
   "kind": "wire",
   "color": "#1D9E75"
  },
  "w_sda2": {
   "a": [
    "AHT",
    "SDA"
   ],
   "b": [
    "BB",
    "T12c"
   ],
   "label": "I²C data: AHT10",
   "note": "",
   "kind": "wire",
   "color": "#1D9E75"
  },
  "w_ads_vdd": {
   "a": [
    "ADS",
    "VDD"
   ],
   "b": [
    "BB",
    "T5b"
   ],
   "label": "ADS1115 power",
   "note": "",
   "kind": "wire",
   "color": "#EF9F27"
  },
  "w_ads_gnd": {
   "a": [
    "ADS",
    "GND"
   ],
   "b": [
    "BB",
    "B2f"
   ],
   "label": "ADS1115 ground",
   "note": "",
   "kind": "wire",
   "color": "#5F5E5A"
  },
  "w_ads_addr": {
   "a": [
    "ADS",
    "ADDR"
   ],
   "b": [
    "BB",
    "B2g"
   ],
   "label": "ADS1115 address select to ground",
   "note": "Sets I²C address 0x48.",
   "kind": "wire",
   "color": "#5F5E5A"
  },
  "w_aht_vin": {
   "a": [
    "AHT",
    "VIN"
   ],
   "b": [
    "BB",
    "T5c"
   ],
   "label": "AHT10 power",
   "note": "",
   "kind": "wire",
   "color": "#EF9F27"
  },
  "w_aht_gnd": {
   "a": [
    "AHT",
    "GND"
   ],
   "b": [
    "BB",
    "B2h"
   ],
   "label": "AHT10 ground",
   "note": "",
   "kind": "wire",
   "color": "#5F5E5A"
  },
  "w_ad_3v3": {
   "a": [
    "AD",
    "3V3"
   ],
   "b": [
    "BB",
    "T6a"
   ],
   "label": "AD8232 power",
   "note": "",
   "kind": "wire",
   "color": "#EF9F27"
  },
  "w_ad_gnd": {
   "a": [
    "AD",
    "GND"
   ],
   "b": [
    "BB",
    "B3g"
   ],
   "label": "AD8232 ground",
   "note": "",
   "kind": "wire",
   "color": "#5F5E5A"
  },
  "w_a0": {
   "a": [
    "ADS",
    "A0"
   ],
   "b": [
    "BB",
    "T3a"
   ],
   "label": "Battery sense to ADS1115 A0",
   "note": "Half the switched battery voltage, 1.5–2.1 V.",
   "kind": "wire",
   "color": "#5DCAA5"
  },
  "w_a3": {
   "a": [
    "ADS",
    "A3"
   ],
   "b": [
    "BB",
    "T8a"
   ],
   "label": "Thermistor node to ADS1115 A3",
   "note": "The safety-critical temperature reading.",
   "kind": "wire",
   "color": "#993C1D"
  },
  "w_ntc_a": {
   "a": [
    "NTC",
    "A"
   ],
   "b": [
    "BB",
    "T8b"
   ],
   "label": "Thermistor lead A to its divider node",
   "note": "Dedicated wire from the bead on the heater. Twist it with lead B.",
   "kind": "wire",
   "color": "#993C1D"
  },
  "w_ntc_b": {
   "a": [
    "NTC",
    "B"
   ],
   "b": [
    "BB",
    "B3h"
   ],
   "label": "Thermistor lead B to ground",
   "note": "Dedicated wire. Twist it with lead A.",
   "kind": "wire",
   "color": "#993C1D"
  },
  "w_alert": {
   "a": [
    "ADS",
    "ALERT"
   ],
   "b": [
    "ESP",
    "G6"
   ],
   "label": "ADS1115 data-ready to GPIO6",
   "note": "Falling edge means a new conversion is ready.",
   "kind": "wire",
   "color": "#7F77DD"
  },
  "w_emg": {
   "a": [
    "AD",
    "OUT"
   ],
   "b": [
    "ESP",
    "G1"
   ],
   "label": "Raw EMG to GPIO1 (ADC1)",
   "note": "Sampled at 1–2 kHz by the ESP32's own ADC. Filtering and the envelope happen in firmware.",
   "kind": "wire",
   "color": "#D85A30"
  },
  "w_lop": {
   "a": [
    "AD",
    "LOP"
   ],
   "b": [
    "ESP",
    "G7"
   ],
   "label": "Lead-off + to GPIO7",
   "note": "High when an electrode loses the skin.",
   "kind": "wire",
   "color": "#7F77DD"
  },
  "w_lon": {
   "a": [
    "AD",
    "LON"
   ],
   "b": [
    "ESP",
    "G10"
   ],
   "label": "Lead-off − to GPIO10",
   "note": "High when an electrode loses the skin.",
   "kind": "wire",
   "color": "#7F77DD"
  },
  "w_sdn": {
   "a": [
    "AD",
    "SDN"
   ],
   "b": [
    "ESP",
    "G12"
   ],
   "label": "AD8232 shutdown from GPIO12",
   "note": "Low puts the AD8232 to sleep between sessions.",
   "kind": "wire",
   "color": "#7F77DD"
  },
  "w_pwm_h": {
   "a": [
    "ESP",
    "G4"
   ],
   "b": [
    "DRV",
    "IN1"
   ],
   "label": "Heater PWM: GPIO4 to IN1",
   "note": "One LEDC channel at 20 kHz or more.",
   "kind": "wire",
   "color": "#D4537E"
  },
  "w_pwm_m": {
   "a": [
    "ESP",
    "G21"
   ],
   "b": [
    "DRV",
    "IN3"
   ],
   "label": "Motor PWM: GPIO21 to IN3",
   "note": "One LEDC channel at 20 kHz or more, duty capped at ~70 %.",
   "kind": "wire",
   "color": "#D4537E"
  },
  "w_slp": {
   "a": [
    "ESP",
    "G11"
   ],
   "b": [
    "DRV",
    "EEP"
   ],
   "label": "Driver sleep: GPIO11 to nSLEEP",
   "note": "Low turns both bridges off. A second heater kill that works even if a PWM pin is stuck. Pulled low at boot.",
   "kind": "wire",
   "color": "#8E1F55"
  },
  "w_tie2": {
   "a": [
    "TIE2",
    "p"
   ],
   "b": [
    "DRV",
    "IN2"
   ],
   "label": "IN2 held at ground",
   "note": "Short jumper.",
   "kind": "lead",
   "color": "#5F5E5A"
  },
  "w_tie4": {
   "a": [
    "TIE4",
    "p"
   ],
   "b": [
    "DRV",
    "IN4"
   ],
   "label": "IN4 held at ground",
   "note": "Short jumper.",
   "kind": "lead",
   "color": "#5F5E5A"
  },
  "w_h1": {
   "a": [
    "DRV",
    "OUT1"
   ],
   "b": [
    "HTR",
    "+"
   ],
   "label": "Heater + (harness pin 1)",
   "note": "",
   "kind": "wire",
   "color": "#BA7517"
  },
  "w_h2": {
   "a": [
    "DRV",
    "OUT2"
   ],
   "b": [
    "TCO",
    "1"
   ],
   "label": "Heater return into the thermal cutoff",
   "note": "",
   "kind": "wire",
   "color": "#BA7517"
  },
  "w_h3": {
   "a": [
    "TCO",
    "2"
   ],
   "b": [
    "HTR",
    "-"
   ],
   "label": "Thermal cutoff to heater − (harness pin 2)",
   "note": "The cutoff sits in series, so opening it stops the heater current.",
   "kind": "wire",
   "color": "#BA7517"
  },
  "w_m1": {
   "a": [
    "DRV",
    "OUT3"
   ],
   "b": [
    "MOT",
    "+"
   ],
   "label": "Motor + (harness pin 5)",
   "note": "",
   "kind": "wire",
   "color": "#73726c"
  },
  "w_m2": {
   "a": [
    "DRV",
    "OUT4"
   ],
   "b": [
    "MOT",
    "-"
   ],
   "label": "Motor − (harness pin 6)",
   "note": "",
   "kind": "wire",
   "color": "#73726c"
  },
  "w_ea": {
   "a": [
    "AD",
    "RA"
   ],
   "b": [
    "EL",
    "A"
   ],
   "label": "Electrode A lead (harness pin 7)",
   "note": "Shielded or twisted EMG cable.",
   "kind": "wire",
   "color": "#9A9890"
  },
  "w_eb": {
   "a": [
    "AD",
    "LA"
   ],
   "b": [
    "EL",
    "B"
   ],
   "label": "Electrode B lead (harness pin 8)",
   "note": "",
   "kind": "wire",
   "color": "#9A9890"
  },
  "w_er": {
   "a": [
    "AD",
    "RL"
   ],
   "b": [
    "EL",
    "REF"
   ],
   "label": "Reference electrode lead (harness pin 9)",
   "note": "",
   "kind": "wire",
   "color": "#9A9890"
  },
  "l_CADS1": {
   "a": [
    "CADS",
    "1"
   ],
   "b": [
    "ADS",
    "VDD"
   ],
   "label": "C2 lead to ADS VDD",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_CADS2": {
   "a": [
    "CADS",
    "2"
   ],
   "b": [
    "ADS",
    "GND"
   ],
   "label": "C2 lead to ADS GND",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_CAHT1": {
   "a": [
    "CAHT",
    "1"
   ],
   "b": [
    "AHT",
    "VIN"
   ],
   "label": "C3 lead to AHT VIN",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_CAHT2": {
   "a": [
    "CAHT",
    "2"
   ],
   "b": [
    "AHT",
    "GND"
   ],
   "label": "C3 lead to AHT GND",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_CAD1": {
   "a": [
    "CAD",
    "1"
   ],
   "b": [
    "AD",
    "3V3"
   ],
   "label": "C6 lead to AD 3V3",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_CAD2": {
   "a": [
    "CAD",
    "2"
   ],
   "b": [
    "AD",
    "GND"
   ],
   "label": "C6 lead to AD GND",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_C101": {
   "a": [
    "C10",
    "1"
   ],
   "b": [
    "DRV",
    "VM"
   ],
   "label": "C4 lead to DRV VM",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_C102": {
   "a": [
    "C10",
    "2"
   ],
   "b": [
    "DRV",
    "GND"
   ],
   "label": "C4 lead to DRV GND",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_C1001": {
   "a": [
    "C100",
    "1"
   ],
   "b": [
    "DRV",
    "VM"
   ],
   "label": "C5 lead to DRV VM",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "l_C1002": {
   "a": [
    "C100",
    "2"
   ],
   "b": [
    "DRV",
    "GND"
   ],
   "label": "C5 lead to DRV GND",
   "note": "Soldered at the module pin.",
   "kind": "lead",
   "color": "#888780"
  },
  "br_33": {
   "a": [
    "BB",
    "T5e"
   ],
   "b": [
    "BB",
    "T6e"
   ],
   "label": "Breadboard bridge",
   "note": "Joins two strips into one net.",
   "kind": "bridge",
   "color": "#EF9F27"
  },
  "br_g12": {
   "a": [
    "BB",
    "B1i"
   ],
   "b": [
    "BB",
    "B2i"
   ],
   "label": "Breadboard bridge",
   "note": "Joins two strips into one net.",
   "kind": "bridge",
   "color": "#444441"
  },
  "br_g23": {
   "a": [
    "BB",
    "B2j"
   ],
   "b": [
    "BB",
    "B3j"
   ],
   "label": "Breadboard bridge",
   "note": "Joins two strips into one net.",
   "kind": "bridge",
   "color": "#444441"
  },
  "br_g39": {
   "a": [
    "BB",
    "B3i"
   ],
   "b": [
    "BB",
    "B9i"
   ],
   "label": "Breadboard bridge",
   "note": "Joins two strips into one net.",
   "kind": "bridge",
   "color": "#444441"
  }
 },
 "strips": {
  "T1": {
   "net": "Switched battery (3.0–4.2 V)",
   "power": true
  },
  "T3": {
   "net": "Battery ÷ 2 → ADS1115 A0",
   "power": false
  },
  "T5": {
   "net": "3.3 V rail (regulator output)",
   "power": true
  },
  "T6": {
   "net": "3.3 V rail (regulator output)",
   "power": true
  },
  "T8": {
   "net": "Thermistor node → ADS1115 A3",
   "power": false
  },
  "T9": {
   "net": "ESP32 3.3 V (after flash link J1)",
   "power": true
  },
  "T11": {
   "net": "I²C SCL bus",
   "power": false
  },
  "T12": {
   "net": "I²C SDA bus",
   "power": false
  },
  "B1": {
   "net": "Ground (sensor / logic)",
   "power": true
  },
  "B2": {
   "net": "Ground (sensor / logic)",
   "power": true
  },
  "B3": {
   "net": "Ground (sensor / logic)",
   "power": true
  },
  "B9": {
   "net": "Ground (sensor / logic)",
   "power": true
  }
 }
};

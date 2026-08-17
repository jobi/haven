import Foundation
import NativeHACore

public struct MockDataFixtures {
    
    public static let sampleLovelaceConfigJSON = """
    {
      "title": "Home",
      "views": [
        {
          "title": "Living Room",
          "path": "living-room",
          "icon": "mdi:sofa",
          "type": "sections",
          "max_columns": 3,
          "badges": [
            {
              "type": "entity",
              "entity": "sensor.outdoor_temperature"
            },
            {
              "type": "entity",
              "entity": "binary_sensor.front_door"
            }
          ],
          "sections": [
            {
              "title": "Lighting",
              "icon": "mdi:ceiling-light",
              "cards": [
                {
                  "type": "heading",
                  "heading": "Ceiling Lights",
                  "heading_style": "title"
                },
                {
                  "type": "tile",
                  "entity": "light.living_room_ceiling",
                  "name": "Main Lights",
                  "icon": "mdi:ceiling-light",
                  "features": [
                    { "type": "light-brightness" }
                  ]
                },
                {
                  "type": "tile",
                  "entity": "light.reading_lamp",
                  "name": "Reading Lamp",
                  "icon": "mdi:lamp-desk"
                }
              ]
            },
            {
              "title": "Climate & Environment",
              "icon": "mdi:thermostat",
              "cards": [
                {
                  "type": "gauge",
                  "entity": "sensor.indoor_temperature",
                  "name": "Indoor Temp",
                  "unit": "°C",
                  "min": 10.0,
                  "max": 35.0,
                  "severity": {
                    "green": 20.0,
                    "yellow": 24.0,
                    "red": 28.0
                  }
                },
                {
                  "type": "sensor",
                  "entity": "sensor.indoor_humidity",
                  "name": "Humidity",
                  "icon": "mdi:water-percent"
                }
              ]
            },
            {
              "title": "Controls",
              "cards": [
                {
                  "type": "button",
                  "entity": "scene.movie_night",
                  "name": "Movie Night",
                  "icon": "mdi:movie",
                  "color": "#03A9F4"
                },
                {
                  "type": "entities",
                  "title": "Switches",
                  "entities": [
                    "switch.ac_power",
                    "switch.air_purifier"
                  ]
                },
                {
                  "type": "custom:mushroom-chips-card",
                  "chips": [
                    { "type": "weather" }
                  ]
                }
              ]
            }
          ]
        },
        {
          "title": "Legacy View",
          "path": "legacy",
          "type": "masonry",
          "cards": []
        }
      ]
    }
    """
    
    public static let sampleEntityInitialDumpJSON = """
    {
      "a": {
        "light.living_room_ceiling": {
          "s": "on",
          "a": {
            "friendly_name": "Living Room Ceiling",
            "brightness": 204,
            "supported_color_modes": ["brightness"]
          },
          "lc": 1700000000.0,
          "lu": 1700000000.0
        },
        "sensor.outdoor_temperature": {
          "s": "22.4",
          "a": {
            "friendly_name": "Outdoor Temperature",
            "unit_of_measurement": "°C",
            "device_class": "temperature"
          }
        },
        "binary_sensor.front_door": {
          "s": "off",
          "a": {
            "friendly_name": "Front Door",
            "device_class": "door"
          }
        },
        "switch.ac_power": {
          "s": "on",
          "a": {
            "friendly_name": "AC Power"
          }
        }
      }
    }
    """
    
    public static let sampleEntityDeltaJSON = """
    {
      "c": {
        "light.living_room_ceiling": {
          "+": {
            "s": "off",
            "a": {
              "brightness": 0
            }
          }
        },
        "binary_sensor.front_door": {
          "+": {
            "s": "on"
          }
        }
      }
    }
    """
}

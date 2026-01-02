# SledLink System Diagram

## Tractor Pull Distance Measurement System

```mermaid
flowchart TB
    subgraph SLED["SLED CONTROLLER UNIT - On Sled"]
        direction TB

        MW["Measuring Wheel\n12 inch diameter"]
        ENC["Rotary Encoder\nGHW38-06G1000BMC526\n1000 PPR\n(NPN Open Collector)"]

        S_ESP["ESP32-WROOM-32E"]
        S_PCNT["PCNT Peripheral\nQuadrature 4x\n(Internal Pull-ups)"]
        S_CALC["Distance Calculator"]
        S_TX["ESP-NOW TX\n10 Hz"]
        S_BTN["Reset Button\nDebounced 50ms"]

        S_LCD["16x2 LCD Display"]
        S_USB["5V USB Power"]

        MW --> ENC
        ENC --> S_PCNT
        S_PCNT --> S_CALC
        S_CALC --> S_TX
        S_CALC --> S_LCD
        S_BTN --> S_PCNT
        S_USB --> S_ESP
    end

    subgraph JUDGE["JUDGE CONTROLLER UNIT - Judge Table"]
        direction TB

        J_ESP["ESP32-WROOM-32E"]
        J_RX["ESP-NOW RX\nDistance Data"]
        J_STATE["State Manager"]

        J_LCD["16x2 LCD Display"]
        J_USB["5V USB Power"]

        J_RX --> J_STATE
        J_STATE --> J_LCD
        J_USB --> J_ESP
    end

    subgraph WIRELESS["ESP-NOW WIRELESS LINK"]
        ESPNOW["WiFi Channel 1\n~100ft Range"]
    end

    S_TX -->|"Distance Data\n8 bytes"| ESPNOW
    ESPNOW -->|"Distance Data"| J_RX

    classDef esp32 fill:#2196F3,stroke:#1565C0,color:#fff
    classDef sensor fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef display fill:#FF9800,stroke:#EF6C00,color:#fff
    classDef power fill:#F44336,stroke:#C62828,color:#fff
    classDef wireless fill:#9C27B0,stroke:#6A1B9A,color:#fff
    classDef button fill:#00BCD4,stroke:#00838F,color:#fff

    class S_ESP,J_ESP,S_PCNT,S_CALC,S_TX,J_RX,J_STATE esp32
    class MW,ENC sensor
    class S_LCD,J_LCD display
    class S_USB,J_USB power
    class ESPNOW wireless
    class S_BTN button
```

## Component Legend

| Color | Component Type |
|-------|----------------|
| Blue | ESP32 / Processing |
| Green | Sensors |
| Orange | Displays |
| Red | Power |
| Purple | Wireless |
| Cyan | User Input |

## Data Flow Summary

- **Sled to Judge**: Distance packets (float + timestamp, 8 bytes) transmitted at 10 Hz
- **Reset**: Performed locally on sled controller via reset button
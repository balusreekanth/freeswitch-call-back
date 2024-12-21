# Call Back Feature for FreeSWITCH & FusionPBX

## Overview
This script provides a **call back feature** for **FreeSWITCH** and **FusionPBX**. When one extension tries to call another extension that is busy, this script plays an IVR (Interactive Voice Response) prompting the caller to either press "1" to request a call back or any other key to hang up. If the caller chooses to request a call back, the request is saved in the database and triggered when the called extension becomes available (not busy).

## Features
- Detects when a called extension is busy.
- Plays an IVR asking the caller if they want a call back.
- Saves call back requests in the database.
- Triggers the call back when the called extension is no longer busy.
- Fully integrated with **FreeSWITCH** and **FusionPBX**.

## Requirements
- **FreeSWITCH** version 1.8.x or higher.
- **FusionPBX** version 5.x .
- A working fusionPBX database PostgreSQL for storing call back requests.
- Basic knowledge of FreeSWITCH dialplan and FusionPBX configuration.

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/balusreekanth/freeswitch-call-back.git
   cd call-back-feature
   ./install.sh
## How It Works
1. When an extension tries to call another extension, the system checks if the called extension is busy.
2. If the called extension is busy, the caller is presented with an IVR message asking if they would like a call back.
3. If the caller presses "1", the request is stored in the database with a **pending** status.
4. When the called extension becomes available (no longer busy), the system triggers the call back request and places the call.
5. Once the call back is completed, the entry in the database is deleted.

## IVR Prompt Example
The IVR prompt could say:
- "The person you are calling is currently busy. Press 1 to receive a call back when they are available, or any other key to hang up."

## Example Usage
- **Caller**: Extension 100 calls Extension 200.
- **Called Extension**: Extension 200 is busy.
- **Caller**: IVR prompts the caller to press "1" for a callback.
- **Caller presses "1"**: The call back request is stored in the database.
- **Extension 200 becomes free**: The system automatically calls Extension 100 back.



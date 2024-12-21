# Call Back Feature for FreeSWITCH & FusionPBX

## Overview
This script provides a **call back feature** for **FreeSWITCH** and **FusionPBX**. When one extension tries to call another extension that is busy, this script plays an IVR (Interactive Voice Response) prompting the caller to either press "1" to request a call back or any other key to hang up. If the caller chooses to request a call back, the request is saved in the database and triggered when the called extension becomes available (not busy).

## Features
- Detects when a called extension is busy.
- Plays an IVR asking the caller if they want a call back.
- Saves call back requests in the database.
- Triggers the call-back when both the called extension and the requested party are no longer busy.
- Option to choose the call-back method: Conference room or user-to-user calling.
- Fully integrated with **FreeSWITCH** and **FusionPBX**.

## Requirements


- [**FreeSWITCH**](https://github.com/signalwire/freeswitch) version 1.8.x or higher.
- [**FusionPBX**](https://github.com/fusionpbx/fusionpbx) version 5.x .
- A working fusionPBX database PostgreSQL for storing call back requests.
- Basic knowledge of FreeSWITCH dialplan and FusionPBX configuration.

## Installation

### 1. **Clone the repository**:
   ```bash
   git clone https://github.com/balusreekanth/freeswitch-call-back.git
   cd freeswitch-call-back
   chmod +x install.sh
   ./install.sh
```
### 2. **Add a Dialplan**
To enable call-back functionality, you need to add a dialplan with the highest priority to check the dialed extension's status. This can be configured using the FusionPBX Dialplan Manager.

Below is an example dialplan:

```xml
<condition field="destination_number" expression="^\d+$">
    <action application="log" data="WARNING Checking activity status for extension ${destination_number}"/>
    <action application="lua" data="dest_exist.lua ${destination_number} ${caller_id_number} ${domain_name}"/>
    <action application="log" data="WARNING extension activity status is ${sip_dialogs_status}"/>
    <action application="sleep" data="200"/>
</condition>
```
- By default, the system uses the **conference** method for call-backs. This means both parties will be added to a conference room when the call-back is triggered.
If you prefer to use the originate method (direct extension-to-extension call), update the configuration in the call-b.py script.
- The system checks for pending call-backs every 15 seconds. You can adjust this timer to increase or decrease the interval as needed.


## How It Works
1. When an extension tries to call another extension, the system checks if the called extension is busy.
2. If the called extension is busy, the caller is presented with an IVR message asking if they would like a call back.
3. If the caller presses "1", the request is stored in the database with a **pending** status.
4. When the called extension becomes available (no longer busy), the system triggers the call back request and places the call.
5. Once the call back is completed, the entry in the database is deleted.


## Is There Any Other Effective Way for a Scalable Solution?

This script queries the FreeSWITCH database for extension status and polls periodically. However, you can achieve a similar functionality more efficiently by using the FreeSWITCH Event Socket Library. With the Event Socket Library, you can subscribe to call events and handle call-backs in real-time, eliminating the need for periodic polling.

## IVR Prompt Example
The IVR prompt could say:
- "The dialed extenion is busy. Press 1 for a call back or press 2 for disconenct the call."
- You can record your own IVR and replace the wav file.


## Example Usage
- **Caller**: Extension 100 calls Extension 200.
- **Called Extension**: Extension 200 is busy.
- **Caller**: IVR prompts the caller to press "1" for a callback.
- **Caller presses "1"**: The call back request is stored in the database.
- **Extension 200 becomes free**: The system automatically calls Extension 100 back.

# Need help ?

- Write your comments and issues in issues section of this repository . Or you can mail at balusreekanthATgmailDOTcom

# Would you like to improve this ?
- I Love to  see pull requests to improve this script further . 



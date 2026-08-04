# Sky Phone

Sky Phone models physical handsets and optional iFruit cloud identities independently from the characters who currently carry them.

## Language

**Device**:
A physical phone represented by one inventory item and identified by one IMEI.
_Avoid_: Player phone, character phone

**IMEI**:
The permanent 15-digit identity of a Device.
_Avoid_: Owner ID, player ID

**Device Data**:
Information that stays with one Device when it is transferred, including settings and alarms.
_Avoid_: Player data, localStorage

**iFruit Account**:
An optional identity that can be linked to several Devices and owns cloud information such as Mail and synced Notes.
_Avoid_: Player account, character account, mail account

**Cloud Data**:
Information owned by an iFruit Account and available on every Device linked to it.
_Avoid_: Device Data, local data

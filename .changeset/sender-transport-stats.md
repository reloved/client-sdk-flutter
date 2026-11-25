---
livekit_client: minor
---

`VideoSenderStats` also reports `qualityLimitationDurations`, `targetBitrate`, `framesEncoded` and `totalEncodeTime` for each layer, and the `availableOutgoingBitrate` and `networkType` of the transport the layer is sent over, read from the stats the monitor already fetches

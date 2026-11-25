// Copyright 2024 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/foundation.dart' show kIsWeb;

import 'audio_source_stats.dart';

const monitorFrequency = 2000;

class CodecStats {
  String? mimeType;
  num? payloadType;
  num? channels;
  num? clockRate;
}

// key stats for senders and receivers
class SenderStats extends CodecStats {
  SenderStats(this.streamId, this.timestamp);

  /// number of packets sent
  num? packetsSent;

  /// number of bytes sent
  num? bytesSent;

  /// jitter as perceived by remote
  num? jitter;

  /// packets reported lost by remote
  num? packetsLost;

  /// RTT reported by remote
  num? roundTripTime;

  /// ID of the outbound stream
  String streamId;

  String? encoderImplementation;

  num timestamp;
}

class AudioSenderStats extends SenderStats {
  AudioSenderStats(String streamId, num timestamp) : super(streamId, timestamp);
  AudioSourceStats? audioSourceStats;
}

class VideoSenderStats extends SenderStats {
  VideoSenderStats(String streamId, num timestamp) : super(streamId, timestamp);

  num? firCount;

  num? pliCount;

  num? nackCount;

  String? rid;

  num? frameWidth;

  num? frameHeight;

  num? framesSent;

  num? framesPerSecond;

  // bandwidth, cpu, other, none
  String? qualityLimitationReason;

  num? qualityLimitationResolutionChanges;

  /// Seconds spent in each limitation state (`none`, `bandwidth`, `cpu`,
  /// `other`) since the layer started
  Map<String, num>? qualityLimitationDurations;

  num? retransmittedPacketsSent;

  /// Bitrate the encoder is currently aiming for, in bits per second
  num? targetBitrate;

  num? framesEncoded;

  /// Seconds spent encoding [framesEncoded]
  num? totalEncodeTime;

  /// The sender's estimate of how much it can send over the selected
  /// candidate pair, in bits per second. Shared by every layer on the same
  /// transport.
  num? availableOutgoingBitrate;

  /// Type of network the selected local candidate uses, e.g. `wifi`,
  /// `cellular`, `ethernet` or `vpn`
  String? networkType;
}

class ReceiverStats extends CodecStats {
  ReceiverStats(this.streamId, this.timestamp);
  num? jitterBufferDelay;

  /// packets reported lost by remote
  num? packetsLost;

  /// number of packets sent
  num? packetsReceived;

  num? bytesReceived;

  String streamId;

  num? jitter;

  num timestamp;
}

class AudioReceiverStats extends ReceiverStats {
  AudioReceiverStats(String streamId, num timestamp) : super(streamId, timestamp);

  num? concealedSamples;

  num? concealmentEvents;

  num? silentConcealedSamples;

  num? silentConcealmentEvents;

  num? totalAudioEnergy;

  num? totalSamplesDuration;

  AudioSourceStats? audioSourceStats;
}

class VideoReceiverStats extends ReceiverStats {
  VideoReceiverStats(String streamId, num timestamp) : super(streamId, timestamp);

  num? framesDecoded;

  num? framesDropped;

  num? framesReceived;

  num? framesPerSecond;

  num? frameWidth;

  num? frameHeight;

  num? firCount;

  num? pliCount;

  num? nackCount;

  String? decoderImplementation;
}

num computeBitrateForSenderStats(
  SenderStats currentStats,
  SenderStats? prevStats,
) {
  if (prevStats == null) {
    return 0;
  }
  num? bytesNow;
  num? bytesPrev;
  bytesNow = currentStats.bytesSent;
  bytesPrev = prevStats.bytesSent;
  if (bytesNow == null || bytesPrev == null) {
    return 0;
  }
  if (kIsWeb) {
    return ((bytesNow - bytesPrev) * 8) / (currentStats.timestamp - prevStats.timestamp);
  }

  return ((bytesNow - bytesPrev) * 8 * 1000) / (currentStats.timestamp - prevStats.timestamp);
}

num computeBitrateForReceiverStats(
  ReceiverStats currentStats,
  ReceiverStats? prevStats,
) {
  if (prevStats == null) {
    return 0;
  }
  num? bytesNow;
  num? bytesPrev;

  bytesNow = currentStats.bytesReceived;
  bytesPrev = prevStats.bytesReceived;

  if (bytesNow == null || bytesPrev == null) {
    return 0;
  }
  if (kIsWeb) {
    return ((bytesNow - bytesPrev) * 8) / (currentStats.timestamp - prevStats.timestamp);
  }

  return ((bytesNow - bytesPrev) * 8 * 1000) / (currentStats.timestamp - prevStats.timestamp);
}

num? getNumValFromReport(Map<dynamic, dynamic> values, String key) {
  if (values.containsKey(key)) {
    return (values[key] is String) ? num.tryParse(values[key]) : values[key] as num;
  }
  return null;
}

String? getStringValFromReport(Map<dynamic, dynamic> values, String key) {
  if (values.containsKey(key)) {
    return values[key] as String;
  }
  return null;
}

/// Like [getNumValFromReport], but null instead of throwing when the value is
/// neither a number nor a numeric string.
num? tryNumValFromReport(Map<dynamic, dynamic> values, String key) {
  final value = values[key];
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// Like [getStringValFromReport], but null instead of throwing when the value
/// isn't a string.
String? tryStringValFromReport(Map<dynamic, dynamic> values, String key) {
  final value = values[key];
  return value is String ? value : null;
}

/// A map of numbers, such as `qualityLimitationDurations`. Entries whose value
/// isn't a number are left out.
Map<String, num>? tryNumMapValFromReport(Map<dynamic, dynamic> values, String key) {
  final value = values[key];
  if (value is! Map) return null;
  return {
    for (final MapEntry(:key, :value) in value.entries)
      if (key is String && value is num) key: value,
  };
}

bool getBoolValFromReport(Map<dynamic, dynamic> values, String key) {
  if (values.containsKey(key) && values[key] is bool) {
    return values[key] as bool;
  }
  return false;
}

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

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:mockito/mockito.dart';

import 'package:livekit_client/src/track/local/video.dart';
import 'package:livekit_client/src/track/options.dart';
import 'package:livekit_client/src/types/other.dart';
import '../mock/mediastream_mock.dart';

class _Sender extends Mock implements rtc.RTCRtpSender {
  List<rtc.StatsReport> reports = [];

  @override
  Future<List<rtc.StatsReport>> getStats() async => reports;
}

class _Transceiver extends Mock implements rtc.RTCRtpTransceiver {
  _Transceiver(this._sender);

  final rtc.RTCRtpSender _sender;

  @override
  rtc.RTCRtpSender get sender => _sender;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LocalVideoTrack createTrack(_Sender sender) {
    return LocalVideoTrack(
      TrackSource.camera,
      FakeMediaStream('stream-1'),
      FakeMediaStreamTrack(id: 'video-1', kind: 'video'),
      const CameraCaptureOptions(),
    )..transceiver = _Transceiver(sender);
  }

  rtc.StatsReport outbound(String rid, Map<String, dynamic> values) {
    return rtc.StatsReport('outbound-$rid', 'outbound-rtp', 1, {'rid': rid, 'transportId': 'transport', ...values});
  }

  final transport = rtc.StatsReport('transport', 'transport', 1, {'selectedCandidatePairId': 'pair'});
  final pair = rtc.StatsReport('pair', 'candidate-pair', 1, {
    'localCandidateId': 'local',
    'availableOutgoingBitrate': 2100000,
  });
  final local = rtc.StatsReport('local', 'local-candidate', 1, {'networkType': 'cellular'});

  test('reports why a layer is held back and what the encoder aims for', () async {
    final sender = _Sender()
      ..reports = [
        outbound('f', {
          'qualityLimitationReason': 'bandwidth',
          'qualityLimitationDurations': {'none': 12.5, 'bandwidth': 40.25, 'cpu': 0, 'other': 0},
          'targetBitrate': 1200000,
          'framesEncoded': 900,
          'framesSent': 870,
          'totalEncodeTime': 4.5,
        }),
      ];
    final track = createTrack(sender);

    final stats = (await track.getSenderStats()).single;

    expect(stats.qualityLimitationReason, 'bandwidth');
    expect(stats.qualityLimitationDurations, {'none': 12.5, 'bandwidth': 40.25, 'cpu': 0, 'other': 0});
    expect(stats.targetBitrate, 1200000);
    expect(stats.framesEncoded, 900);
    expect(stats.framesSent, 870);
    expect(stats.totalEncodeTime, 4.5);
    await track.dispose();
  });

  test('every layer reports the estimate and network of the transport it is sent over', () async {
    final sender = _Sender()..reports = [local, outbound('q', {}), pair, outbound('f', {}), transport];
    final track = createTrack(sender);

    final stats = await track.getSenderStats();

    expect(stats.map((s) => s.availableOutgoingBitrate), [2100000, 2100000]);
    expect(stats.map((s) => s.networkType), ['cellular', 'cellular']);
    await track.dispose();
  });

  test('missing or malformed values are left out without failing the other stats', () async {
    for (final reports in [
      [
        outbound('f', {'framesSent': 10}),
      ],
      [
        outbound('f', {'framesSent': 10, 'transportId': 'nowhere'}),
        rtc.StatsReport('transport', 'transport', 1, {'selectedCandidatePairId': 'nowhere'}),
      ],
      [
        outbound('f', {
          'framesSent': 10,
          'qualityLimitationDurations': 'not a map',
          'targetBitrate': {'unexpected': true},
          'transportId': 42,
        }),
        transport,
        pair,
        local,
      ],
    ]) {
      final track = createTrack(_Sender()..reports = reports);

      final stats = (await track.getSenderStats()).single;

      expect(stats.framesSent, 10);
      expect(stats.qualityLimitationDurations, isNull);
      expect(stats.targetBitrate, isNull);
      expect(stats.availableOutgoingBitrate, isNull);
      expect(stats.networkType, isNull);
      await track.dispose();
    }
  });
}

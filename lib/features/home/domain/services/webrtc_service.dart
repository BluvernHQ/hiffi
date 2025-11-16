import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

import '../../../../core/constants/webrtc_constants.dart';

class WebRtcService {
  webrtc.RTCPeerConnection? _peerConnection;
  webrtc.MediaStream? _localStream;

  Future<webrtc.RTCPeerConnection> createPeerConnection() async {
    return webrtc.createPeerConnection(defaultIceConfiguration, {});
  }

  Future<void> replacePeerConnection(
    webrtc.RTCPeerConnection peerConnection,
  ) async {
    await _peerConnection?.close();
    _peerConnection = peerConnection;
  }

  Future<webrtc.MediaStream> createLocalStream() async {
    final stream = await webrtc.navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _disposeLocalStream();
    _localStream = stream;
    return stream;
  }

  Future<void> attachStream(
    webrtc.RTCPeerConnection peerConnection,
    webrtc.MediaStream stream,
  ) async {
    for (final track in stream.getTracks()) {
      await peerConnection.addTrack(track, stream);
    }
  }

  Future<webrtc.RTCSessionDescription> createOffer(
    webrtc.RTCPeerConnection peerConnection,
  ) async {
    final offer = await peerConnection.createOffer(defaultOfferSdpConstraints);
    await peerConnection.setLocalDescription(offer);
    return offer;
  }

  void _disposeLocalStream() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
  }

  void dispose() {
    _disposeLocalStream();
    _peerConnection?.close();
    _peerConnection = null;
  }
}

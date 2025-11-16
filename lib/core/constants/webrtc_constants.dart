const Map<String, dynamic> defaultIceConfiguration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
};

const Map<String, dynamic> defaultOfferSdpConstraints = {
  'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
  'optional': [],
};

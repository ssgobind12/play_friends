import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';
import 'aws_storage_service.dart';

/// Real-Time WebRTC Voice Communication Service for Play Friends Room Voice Chat.
///
/// Handles:
/// - Real-time microphone audio capture with hardware Echo Cancellation & Noise Suppression
/// - Peer-to-peer WebRTC audio streaming between room participants
/// - Automatic speakerphone routing so room audio is loud & clear
/// - Room signaling via AWS DynamoDB / REST polling
/// - Live mute / unmute toggling with instant audio track gating
/// - Speaking detection state tracking for UI wave animations
class VoiceRtcService extends ChangeNotifier {
  static final VoiceRtcService _instance = VoiceRtcService._internal();
  factory VoiceRtcService() => _instance;
  VoiceRtcService._internal();

  /// Testing & headless fallback flag
  static bool mockMode = false;

  String? _currentRoomCode;
  String? _currentUserId;
  String? _currentUserName;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _pendingIceCandidates = {};
  final Set<String> _connectedPeers = {};

  Timer? _signalTimer;
  int _lastSignalTimestamp = 0;

  bool _isMicMuted = false;
  bool _isRoomAudioMuted = false;
  bool _isInitialized = false;

  final Set<String> _speakingUsers = {};

  // Public state notifiers
  bool get isConnected => _connectedPeers.isNotEmpty || _isInitialized;
  bool get isMicMuted => _isMicMuted;
  bool get isRoomAudioMuted => _isRoomAudioMuted;
  String? get currentRoomCode => _currentRoomCode;
  Set<String> get speakingUsers => Set.unmodifiable(_speakingUsers);

  static const Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// Join a voice party room and start live real-time audio communication
  Future<void> joinRoom(
    String roomCode,
    UserModel? user, {
    bool startMuted = false,
  }) async {
    _currentRoomCode = roomCode;
    _currentUserId = (user?.email ?? user?.id ?? 'guest_${DateTime.now().millisecondsSinceEpoch}').toLowerCase().trim();
    _currentUserName = user?.name ?? 'Player';
    _isMicMuted = startMuted;
    _isRoomAudioMuted = false;
    _lastSignalTimestamp = DateTime.now().millisecondsSinceEpoch;

    if (mockMode) {
      _isInitialized = true;
      notifyListeners();
      return;
    }

    // 1. Request microphone permission
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        debugPrint('VoiceRtcService: Microphone permission denied');
      }
    } catch (e) {
      debugPrint('VoiceRtcService permission error: $e');
    }

    // 2. Initialize local microphone audio stream
    try {
      final Map<String, dynamic> audioConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'highPassFilter': true,
        },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(audioConstraints);

      // Apply initial mute state
      setMicrophoneMuted(_isMicMuted);

      // Route audio to speakerphone for party room experience
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('VoiceRtcService getUserMedia error: $e');
      _isInitialized = true; // Still allow listening to other peers
    }

    // 3. Start fast signaling poller
    _startSignalingPoller();
  }

  /// Update active room members to automatically connect to new peers
  Future<void> updateRoomMembers(List<Map<String, dynamic>> members) async {
    if (!_isInitialized || _currentRoomCode == null || _currentUserId == null) return;
    if (mockMode) return;

    for (final member in members) {
      final memberId = (member['userId'] ?? member['id'] ?? member['email'] ?? '').toString().toLowerCase().trim();
      final memberName = (member['name'] ?? 'Player').toString().trim();

      if (memberId.isEmpty || memberId == _currentUserId) continue;

      if (!_peerConnections.containsKey(memberId)) {
        // Deterministic offer initiation: Peer with alphabetically smaller ID creates offer
        final shouldInitiateOffer = _currentUserId!.compareTo(memberId) < 0;

        if (shouldInitiateOffer) {
          debugPrint('VoiceRtcService: Initiating WebRTC offer to peer $memberName ($memberId)');
          await _createPeerOffer(memberId, memberName);
        }
      }
    }
  }

  /// Toggle or set local microphone mute state
  void setMicrophoneMuted(bool muted) {
    _isMicMuted = muted;
    if (!mockMode && _localStream != null) {
      try {
        for (final track in _localStream!.getAudioTracks()) {
          track.enabled = !muted;
        }
      } catch (e) {
        debugPrint('VoiceRtcService setMicrophoneMuted error: $e');
      }
    }
    notifyListeners();
  }

  /// Toggle or set room audio mute state (mute incoming peer voices)
  void setRoomAudioMuted(bool muted) {
    _isRoomAudioMuted = muted;
    if (!mockMode) {
      try {
        Helper.setSpeakerphoneOn(!muted);
      } catch (e) {
        debugPrint('VoiceRtcService setRoomAudioMuted error: $e');
      }
    }
    notifyListeners();
  }

  /// Leave the voice room, closing all connections and releasing audio hardware
  Future<void> leaveRoom() async {
    _signalTimer?.cancel();
    _signalTimer = null;

    for (final pc in _peerConnections.values) {
      try {
        await pc.close();
        await pc.dispose();
      } catch (_) {}
    }
    _peerConnections.clear();
    _pendingIceCandidates.clear();
    _connectedPeers.clear();
    _speakingUsers.clear();

    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream!.dispose();
      } catch (_) {}
      _localStream = null;
    }

    _isInitialized = false;
    _currentRoomCode = null;
    _currentUserId = null;
    _currentUserName = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // WEBRTC PEER CONNECTION & SIGNALING INTERNALS
  // ---------------------------------------------------------------------------

  Future<RTCPeerConnection> _getOrCreatePeerConnection(String peerId, String peerName) async {
    if (_peerConnections.containsKey(peerId)) {
      return _peerConnections[peerId]!;
    }

    final pc = await createPeerConnection(_rtcConfiguration);

    // Add local microphone audio track
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    // ICE Candidate handler
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && _currentRoomCode != null && _currentUserId != null) {
        AwsStorageService.sendVoiceSignal(
          roomId: _currentRoomCode!,
          fromUserId: _currentUserId!,
          fromUserName: _currentUserName ?? 'Player',
          toUserId: peerId,
          signalType: 'candidate',
          signalData: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };

    // Connection state handler
    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('VoiceRtcService peer $peerId state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _connectedPeers.add(peerId);
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _connectedPeers.remove(peerId);
        notifyListeners();
      }
    };

    // Remote audio track received: WebRTC handles playing it to audio hardware
    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio') {
        debugPrint('VoiceRtcService: Received remote voice track from $peerName ($peerId)');
        _connectedPeers.add(peerId);
        _speakingUsers.add(peerName);
        notifyListeners();

        // Simulate speaking indicator pulse for UI
        Timer(const Duration(seconds: 3), () {
          _speakingUsers.remove(peerName);
          notifyListeners();
        });
      }
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  Future<void> _createPeerOffer(String peerId, String peerName) async {
    try {
      final pc = await _getOrCreatePeerConnection(peerId, peerName);
      final offer = await pc.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await pc.setLocalDescription(offer);

      if (_currentRoomCode != null && _currentUserId != null) {
        await AwsStorageService.sendVoiceSignal(
          roomId: _currentRoomCode!,
          fromUserId: _currentUserId!,
          fromUserName: _currentUserName ?? 'Player',
          toUserId: peerId,
          signalType: 'offer',
          signalData: {
            'sdp': offer.sdp,
            'type': offer.type,
          },
        );
      }
    } catch (e) {
      debugPrint('VoiceRtcService _createPeerOffer error: $e');
    }
  }

  Future<void> _handleRemoteOffer(String fromUserId, String fromUserName, Map<String, dynamic> signalData) async {
    try {
      final pc = await _getOrCreatePeerConnection(fromUserId, fromUserName);
      final sdp = signalData['sdp']?.toString() ?? '';
      final type = signalData['type']?.toString() ?? 'offer';

      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));

      // Flush any queued ICE candidates
      final queued = _pendingIceCandidates.remove(fromUserId);
      if (queued != null) {
        for (final c in queued) {
          await pc.addCandidate(c);
        }
      }

      final answer = await pc.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await pc.setLocalDescription(answer);

      if (_currentRoomCode != null && _currentUserId != null) {
        await AwsStorageService.sendVoiceSignal(
          roomId: _currentRoomCode!,
          fromUserId: _currentUserId!,
          fromUserName: _currentUserName ?? 'Player',
          toUserId: fromUserId,
          signalType: 'answer',
          signalData: {
            'sdp': answer.sdp,
            'type': answer.type,
          },
        );
      }
    } catch (e) {
      debugPrint('VoiceRtcService _handleRemoteOffer error: $e');
    }
  }

  Future<void> _handleRemoteAnswer(String fromUserId, Map<String, dynamic> signalData) async {
    try {
      final pc = _peerConnections[fromUserId];
      if (pc != null) {
        final sdp = signalData['sdp']?.toString() ?? '';
        final type = signalData['type']?.toString() ?? 'answer';
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));

        // Flush queued candidates
        final queued = _pendingIceCandidates.remove(fromUserId);
        if (queued != null) {
          for (final c in queued) {
            await pc.addCandidate(c);
          }
        }
      }
    } catch (e) {
      debugPrint('VoiceRtcService _handleRemoteAnswer error: $e');
    }
  }

  Future<void> _handleRemoteCandidate(String fromUserId, Map<String, dynamic> signalData) async {
    try {
      final candidateStr = signalData['candidate']?.toString() ?? '';
      final sdpMid = signalData['sdpMid']?.toString();
      final sdpMLineIndex = signalData['sdpMLineIndex'] is int ? signalData['sdpMLineIndex'] as int : 0;

      final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);

      final pc = _peerConnections[fromUserId];
      if (pc != null) {
        final remoteDesc = await pc.getRemoteDescription();
        if (remoteDesc != null) {
          await pc.addCandidate(candidate);
        } else {
          _pendingIceCandidates.putIfAbsent(fromUserId, () => []).add(candidate);
        }
      } else {
        _pendingIceCandidates.putIfAbsent(fromUserId, () => []).add(candidate);
      }
    } catch (e) {
      debugPrint('VoiceRtcService _handleRemoteCandidate error: $e');
    }
  }

  void _startSignalingPoller() {
    _signalTimer?.cancel();
    _signalTimer = Timer.periodic(const Duration(milliseconds: 750), (_) async {
      if (_currentRoomCode == null || _currentUserId == null || !_isInitialized) return;

      try {
        final signals = await AwsStorageService.getVoiceSignals(
          roomId: _currentRoomCode!,
          userId: _currentUserId!,
          lastTimestamp: _lastSignalTimestamp,
        );

        for (final sig in signals) {
          final ts = (sig['timestamp'] as num?)?.toInt() ?? 0;
          if (ts > _lastSignalTimestamp) {
            _lastSignalTimestamp = ts;
          }

          final fromId = (sig['fromUserId'] ?? '').toString().toLowerCase().trim();
          final fromName = (sig['fromUserName'] ?? 'Player').toString().trim();
          final type = (sig['signalType'] ?? '').toString();
          final data = sig['signalData'] is Map ? Map<String, dynamic>.from(sig['signalData'] as Map) : <String, dynamic>{};

          if (fromId.isEmpty || fromId == _currentUserId) continue;

          switch (type) {
            case 'offer':
              await _handleRemoteOffer(fromId, fromName, data);
              break;
            case 'answer':
              await _handleRemoteAnswer(fromId, data);
              break;
            case 'candidate':
              await _handleRemoteCandidate(fromId, data);
              break;
          }
        }
      } catch (e) {
        // Suppress timer network errors
      }
    });
  }
}

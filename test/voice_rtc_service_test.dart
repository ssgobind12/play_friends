import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/user_model.dart';
import 'package:play_friends/services/aws_storage_service.dart';
import 'package:play_friends/services/voice_rtc_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VoiceRtcService.mockMode = true;
    AwsStorageService.mockMode = true;
    AwsStorageService.resetForTesting();
  });

  tearDown(() async {
    await VoiceRtcService().leaveRoom();
  });

  group('VoiceRtcService Unit Tests', () {
    const userA = UserModel(
      id: 'u_101',
      name: 'Shubham Host',
      tag: '@shubham',
      email: 'shubham@playfriends.io',
      level: 10,
      avatarColor: Colors.purple,
      avatarInitial: 'S',
    );

    const userB = UserModel(
      id: 'u_102',
      name: 'Diksha Player',
      tag: '@diksha',
      email: 'diksha@playfriends.io',
      level: 5,
      avatarColor: Colors.blue,
      avatarInitial: 'D',
    );

    test('joinRoom initializes voice connection and room code', () async {
      final rtc = VoiceRtcService();
      expect(rtc.isConnected, isFalse);
      expect(rtc.currentRoomCode, isNull);

      await rtc.joinRoom('PF-7788', userA);

      expect(rtc.isConnected, isTrue);
      expect(rtc.currentRoomCode, equals('PF-7788'));
      expect(rtc.isMicMuted, isFalse);
      expect(rtc.isRoomAudioMuted, isFalse);
    });

    test('setMicrophoneMuted toggles mic state and notifies listeners', () async {
      final rtc = VoiceRtcService();
      await rtc.joinRoom('PF-7788', userA);

      bool notified = false;
      rtc.addListener(() => notified = true);

      rtc.setMicrophoneMuted(true);
      expect(rtc.isMicMuted, isTrue);
      expect(notified, isTrue);

      notified = false;
      rtc.setMicrophoneMuted(false);
      expect(rtc.isMicMuted, isFalse);
      expect(notified, isTrue);
    });

    test('setRoomAudioMuted toggles incoming room speaker audio', () async {
      final rtc = VoiceRtcService();
      await rtc.joinRoom('PF-7788', userA);

      rtc.setRoomAudioMuted(true);
      expect(rtc.isRoomAudioMuted, isTrue);

      rtc.setRoomAudioMuted(false);
      expect(rtc.isRoomAudioMuted, isFalse);
    });

    test('AwsStorageService voice signaling relays offer, answer, and candidates between peers', () async {
      const roomCode = 'PF-7788';

      // 1. User A sends an offer to User B
      final sentOffer = await AwsStorageService.sendVoiceSignal(
        roomId: roomCode,
        fromUserId: userA.id,
        fromUserName: userA.name,
        toUserId: userB.id,
        signalType: 'offer',
        signalData: {'sdp': 'v=0\r\no=mock_sdp_audio', 'type': 'offer'},
      );
      expect(sentOffer, isTrue);

      // 2. User B queries voice signals and receives the offer
      final signalsForB = await AwsStorageService.getVoiceSignals(
        roomId: roomCode,
        userId: userB.id,
      );
      expect(signalsForB, isNotEmpty);
      expect(signalsForB.first['signalType'], equals('offer'));
      expect(signalsForB.first['fromUserId'], equals(userA.id));

      // 3. User B replies with an answer to User A
      final sentAnswer = await AwsStorageService.sendVoiceSignal(
        roomId: roomCode,
        fromUserId: userB.id,
        fromUserName: userB.name,
        toUserId: userA.id,
        signalType: 'answer',
        signalData: {'sdp': 'v=0\r\no=mock_sdp_answer', 'type': 'answer'},
      );
      expect(sentAnswer, isTrue);

      // 4. User A queries voice signals and receives the answer
      final signalsForA = await AwsStorageService.getVoiceSignals(
        roomId: roomCode,
        userId: userA.id,
      );
      expect(signalsForA, isNotEmpty);
      expect(signalsForA.any((s) => s['signalType'] == 'answer'), isTrue);
    });

    test('leaveRoom resets connection state, room code, and speaking users', () async {
      final rtc = VoiceRtcService();
      await rtc.joinRoom('PF-7788', userA);
      expect(rtc.isConnected, isTrue);

      await rtc.leaveRoom();
      expect(rtc.isConnected, isFalse);
      expect(rtc.currentRoomCode, isNull);
      expect(rtc.speakingUsers, isEmpty);
    });
  });
}

class RoomModel {
  final String id;
  final String roomCode;
  final String gameTitle;
  final String hostName;
  final String? hostPhoto;
  final int currentPlayers;
  final int maxPlayers;
  final bool isPrivate;
  final String status;
  final int giftPoints;

  const RoomModel({
    required this.id,
    required this.roomCode,
    required this.gameTitle,
    required this.hostName,
    this.hostPhoto,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.isPrivate,
    required this.status,
    this.giftPoints = 0,
  });

  static bool isDemoRoom(RoomModel room) {
    final code =
        room.roomCode.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final id = room.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final host = room.hostName.toLowerCase();
    final title = room.gameTitle.toLowerCase();

    // Check specific known demo room numbers/codes
    const demoNumbers = [
      '5050',
      '4912',
      '1034',
      '8821',
      '2041',
      '5519',
      '3390',
      '1204',
      '7731',
      '9999',
    ];
    for (final num in demoNumbers) {
      if (code.contains(num) || id.contains(num)) return true;
    }

    if (id.contains('seed') || code.contains('seed')) return true;

    // Check fake/demo host keywords
    const demoHostKeywords = [
      'kabir',
      'aanya',
      'annya',
      'anya',
      'rohan',
      'priya',
      'vikram',
      'brinda',
      'simplychetana',
      'chetana',
      'pragati',
      'alex vance',
      'cutie',
      'deepak',
      'pooja',
      'game friends',
    ];
    for (final h in demoHostKeywords) {
      if (host.contains(h)) return true;
    }

    // Check fake/demo title keywords
    const demoTitleKeywords = [
      'game friends',
      'bollywood',
      'ludo friends & gift',
      'chill lounge & songs',
      'late night jam',
      'pro gamer arena',
      'ludo masters club',
      'cyber neon arena',
      'mega chalo party',
    ];
    for (final t in demoTitleKeywords) {
      if (title.contains(t)) return true;
    }

    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomCode': roomCode,
      'gameTitle': gameTitle,
      'hostName': hostName,
      'hostPhoto': hostPhoto,
      'currentPlayers': currentPlayers,
      'maxPlayers': maxPlayers,
      'isPrivate': isPrivate,
      'status': status,
      'giftPoints': giftPoints,
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id']?.toString() ?? '',
      roomCode: map['roomCode']?.toString() ?? '',
      gameTitle: map['gameTitle']?.toString() ?? 'Game Room',
      hostName: map['hostName']?.toString() ?? 'Host',
      hostPhoto: map['hostPhoto']?.toString(),
      currentPlayers:
          map['currentPlayers'] is int ? map['currentPlayers'] as int : 1,
      maxPlayers: map['maxPlayers'] is int ? map['maxPlayers'] as int : 100,
      isPrivate: map['isPrivate'] == true,
      status: map['status']?.toString() ?? 'Live Voice Party',
      giftPoints: map['giftPoints'] is int ? map['giftPoints'] as int : 0,
    );
  }

  RoomModel copyWith({
    String? id,
    String? roomCode,
    String? gameTitle,
    String? hostName,
    String? hostPhoto,
    int? currentPlayers,
    int? maxPlayers,
    bool? isPrivate,
    String? status,
    int? giftPoints,
  }) {
    return RoomModel(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      gameTitle: gameTitle ?? this.gameTitle,
      hostName: hostName ?? this.hostName,
      hostPhoto: hostPhoto ?? this.hostPhoto,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isPrivate: isPrivate ?? this.isPrivate,
      status: status ?? this.status,
      giftPoints: giftPoints ?? this.giftPoints,
    );
  }
}

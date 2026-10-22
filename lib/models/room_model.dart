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
    const demoCodes = [
      'PF-8821',
      'PF-2041',
      'PF-5519',
      'PF-3390',
      'PF-1204',
      'PF-7731',
      'PF-9999'
    ];
    const demoHosts = [
      'Kabir 👑',
      'Aanya ✨',
      'Rohan 🚀',
      'Priya 💖',
      'Vikram ⚡',
      'Brinda',
      'SimplyChetana',
      'Pragati',
      'Alex Vance',
      'Cutie'
    ];
    const demoTitles = [
      'Bollywood & Gaming',
      'Late Night Jam',
      'Pro Gamer Arena',
      'Ludo Masters Club',
      'Cyber Neon Arena'
    ];

    if (demoCodes.contains(room.roomCode)) return true;
    if (demoHosts.any((h) => room.hostName.contains(h))) return true;
    if (demoTitles.any((t) => room.gameTitle.contains(t))) return true;
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

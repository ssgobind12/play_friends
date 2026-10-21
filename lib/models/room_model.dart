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
      currentPlayers: map['currentPlayers'] is int ? map['currentPlayers'] as int : 1,
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

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

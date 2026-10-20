class RoomModel {
  final String id;
  final String roomCode;
  final String gameTitle;
  final String hostName;
  final int currentPlayers;
  final int maxPlayers;
  final bool isPrivate;
  final String status;

  const RoomModel({
    required this.id,
    required this.roomCode,
    required this.gameTitle,
    required this.hostName,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.isPrivate,
    required this.status,
  });
}

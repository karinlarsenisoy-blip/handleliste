/// A real, physical branch of a grocery chain — from OpenStreetMap, not a
/// chain name in the abstract. `chainName` is the canonicalized chain
/// (e.g. "Kiwi"), `name` is the specific branch's own OSM name if it has
/// one (e.g. "Kiwi Grünerløkka"), falling back to the chain name.
class StoreLocation {
  StoreLocation({
    required this.chainName,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String chainName;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
}

/// A real, physical branch of a grocery chain — from OpenStreetMap, not a
/// chain name in the abstract. `chainName` is the canonicalized chain
/// (e.g. "Kiwi"), `name` is the specific branch's own OSM name if it has
/// one (e.g. "Kiwi Grünerløkka"), falling back to the chain name.
///
/// `branchId` is a stable identifier for this exact physical branch (its
/// OpenStreetMap node id, prefixed to leave room for a different id scheme
/// later without colliding) — different branches of the same chain (e.g.
/// Kiwi Onsøyveien vs. Kiwi Frydenberg) can be laid out completely
/// differently inside, so anything crowdsourced about a specific store's
/// layout has to key off the branch, never just the chain name.
class StoreLocation {
  StoreLocation({
    required this.branchId,
    required this.chainName,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String branchId;
  final String chainName;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
}

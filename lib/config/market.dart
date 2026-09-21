/// The country/market this deployment currently serves. Handleliste only
/// operates in Norway today — this constant exists so that adding a second
/// market later (e.g. Sweden) is a matter of making this a real per-user
/// value and adding `'se'` alongside `'no'` wherever data is keyed by
/// market, rather than retrofitting every price document and chain list
/// after the fact. Nothing reads or writes this as anything other than
/// `'no'` yet — it's groundwork, not a live feature.
const String currentMarket = 'no';

/// The currency written prices are actually denominated in for [market].
/// Kept separate from the *displayed* suffix ("kr"), which stays "kr" for
/// both Norway and a future Sweden regardless of this value — this is only
/// for anything that needs to know the underlying currency, not the label.
String currencyForMarket(String market) => switch (market) {
      'no' => 'NOK',
      'se' => 'SEK',
      _ => throw ArgumentError('Unknown market: $market'),
    };

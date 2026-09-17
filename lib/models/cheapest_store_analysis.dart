import 'shopping_split.dart';
import 'store_total.dart';

/// Both views of the same underlying per-item price lookups, computed
/// together from one shared set of prices so they can never disagree with
/// each other (each view used to re-fetch prices independently, which could
/// give inconsistent results between the two tabs if a live source like
/// Kassalapp returned slightly different matches on the second call).
class CheapestStoreAnalysis {
  CheapestStoreAnalysis({required this.storeTotals, required this.split});

  final List<StoreTotal> storeTotals;
  final ShoppingSplit split;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/currency_repository.dart';
import '../models/currency.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  ref.watch(databaseProvider);
  return CurrencyRepository.instance;
});

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// Every supported currency.
final allCurrenciesProvider = FutureProvider<List<CurrencyInfo>>((ref) async {
  return ref.watch(currencyRepositoryProvider).getAllCurrencies();
});

/// The user's default currency.
final defaultCurrencyProvider = FutureProvider<CurrencyInfo>((ref) async {
  ref.watch(currencyRefreshProvider);
  final repo = ref.watch(currencyRepositoryProvider);
  final code = await repo.getDefaultCurrencyCode();
  return (await repo.getCurrency(code)) ??
      const CurrencyInfo(code: 'CNY', name: '人民币', symbol: '¥');
});

/// All stored exchange rates (raw maps for the management page).
final allExchangeRatesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(currencyRepositoryProvider).getAllRates();
});

/// Get the rate from [fromCode] to [toCode].
final exchangeRateProvider =
    FutureProvider.family<double?, (String, String)>((ref, pair) async {
  return ref.watch(currencyRepositoryProvider).getRate(pair.$1, pair.$2);
});

/// Refresh token for currency data.
final currencyRefreshProvider = StateProvider<int>((_) => 0);

/// Write operations for currency settings.
final currencyMutationsProvider = Provider<CurrencyMutations>((ref) {
  return CurrencyMutations(ref);
});

class CurrencyMutations {
  CurrencyMutations(this._ref);
  final Ref _ref;

  Future<void> setDefaultCurrency(String code) async {
    await _ref.read(currencyRepositoryProvider).setDefaultCurrencyCode(code);
    _ref.read(currencyRefreshProvider.notifier).state++;
  }

  Future<void> setRate(String from, String to, double rate) async {
    await _ref.read(currencyRepositoryProvider).setRate(from, to, rate);
    _ref.read(currencyRefreshProvider.notifier).state++;
  }
}

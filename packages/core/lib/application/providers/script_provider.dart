// packages/core/lib/application/providers/script_provider.dart
final scriptRepositoryProvider = Provider<ScriptRepository>((ref) {
  return ScriptRepositoryImpl();
});

final scriptsProvider = StreamProvider<List<Script>>((ref) {
  final repository = ref.watch(scriptRepositoryProvider);
  return repository.watchScripts();
});

final scrollEngineProvider = Provider.family<ScrollEngine, TickerProvider>(
  (ref, tickerProvider) {
    return SmoothScrollEngine(
      scrollController: ScrollController(),
      tickerProvider: tickerProvider,
    );
  },
);
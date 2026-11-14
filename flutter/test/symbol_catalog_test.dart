import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercalculator_next_era/features/plotting/symbol_catalog.dart';

void main() {
  group('symbol catalog', () {
    test('exposes at least the documented symbol range', () {
      expect(SymbolCatalog.all.length, greaterThanOrEqualTo(60));
      expect(SymbolGroup.values.length, greaterThanOrEqualTo(8));
      for (final group in SymbolGroup.values) {
        expect(
          SymbolCatalog.byGroup(group),
          isNotEmpty,
          reason: 'group ${group.name} should not be empty',
        );
      }
    });

    test('every symbol has a unique id and usable metadata', () {
      final ids = <String>{};
      for (final symbol in SymbolCatalog.all) {
        expect(symbol.id, isNotEmpty);
        expect(ids.add(symbol.id), isTrue, reason: 'duplicate ${symbol.id}');
        expect(symbol.label, isNotEmpty);
        expect(symbol.insertion, isNotEmpty);
        expect(symbol.descriptionEn, isNotEmpty);
        expect(symbol.descriptionZh, isNotEmpty);
      }
    });

    test('caret offsets stay inside the inserted text', () {
      for (final symbol in SymbolCatalog.all) {
        expect(
          symbol.caretBack,
          greaterThanOrEqualTo(0),
          reason: '${symbol.id} has a negative caret offset',
        );
        expect(
          symbol.caretBack,
          lessThanOrEqualTo(symbol.insertion.length),
          reason: '${symbol.id} moves the caret before the insertion start',
        );
      }
    });

    test('wrapping symbols contain an insertion point', () {
      for (final symbol in SymbolCatalog.all.where(
        (MathSymbol symbol) => symbol.wrapsSelection,
      )) {
        expect(
          symbol.insertion.contains('()') ||
              symbol.insertion.startsWith('(') ||
              symbol.insertion.contains('|'),
          isTrue,
          reason: '${symbol.id} wraps a selection but has nowhere to put it',
        );
      }
    });

    test('search matches labels, ids and keywords', () {
      expect(SymbolCatalog.search('sqrt').map((s) => s.id), contains('sqrt'));
      expect(SymbolCatalog.search('pi').map((s) => s.id), contains('pi'));
      expect(SymbolCatalog.search('   '), isEmpty);
    });

    test('byId round-trips and rejects unknown ids', () {
      final first = SymbolCatalog.all.first;
      expect(SymbolCatalog.byId(first.id), same(first));
      expect(SymbolCatalog.byId('does-not-exist'), isNull);
    });
  });

  group('quick symbol store', () {
    test('records recents once, newest first, bounded', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = await QuickSymbolStore.load();
      addTearDown(store.dispose);

      for (var index = 0; index < QuickSymbolStore.maxRecents + 4; index++) {
        store.recordUsage('sym-$index');
      }
      store.recordUsage('sym-5');

      expect(store.recents.length, QuickSymbolStore.maxRecents);
      expect(store.recents.first, 'sym-5');
      expect(
        store.recents.where((String id) => id == 'sym-5').length,
        1,
        reason: 'recents must not contain duplicates',
      );
      expect(store.usage['sym-5'], 2);
    });

    test('favourites toggle and survive a reload', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = await QuickSymbolStore.load();
      final id = SymbolCatalog.all.first.id;
      first.toggleFavorite(id);
      expect(first.favorites, contains(id));
      first.recordUsage(id);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      first.dispose();

      final second = await QuickSymbolStore.load();
      addTearDown(second.dispose);
      expect(second.favorites, contains(id));
      expect(second.recents, contains(id));
      second.toggleFavorite(id);
      expect(second.favorites, isNot(contains(id)));
    });

    test('suggestions prefer used symbols', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = await QuickSymbolStore.load();
      addTearDown(store.dispose);

      store.recordUsage('pi');
      store.recordUsage('pi');
      final suggested = store.suggested;
      expect(suggested, isNotEmpty);
      expect(suggested.first.id, 'pi');
    });
  });
}

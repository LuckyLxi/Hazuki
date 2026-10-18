import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';

void main() {
  const comic = ExploreComic(
    id: 'comic-a',
    sourceKey: 'website',
    title: 'Comic title',
    subTitle: 'Comic subtitle',
    cover: 'https://example.com/cover.jpg',
  );

  test('serialization preserves promotional and comic content separately', () {
    const entry = DiscoverDailyRecommendationEntry(
      comic: comic,
      bannerTitle: 'Weekly picks',
      imageUrl: 'https://example.com/banner.jpg',
      author: 'Editor recommendation',
    );
    final restored = DiscoverDailyRecommendationEntry.fromJson(entry.toJson())!;
    expect(restored.displayTitle, 'Weekly picks');
    expect(restored.displayImageUrl, 'https://example.com/banner.jpg');
    expect(restored.author, 'Editor recommendation');
    expect(restored.comic.id, comic.id);
    expect(restored.comic.sourceKey, comic.sourceKey);
    expect(restored.comic.title, comic.title);
    expect(restored.comic.cover, comic.cover);
    expect(restored.comic.subTitle, comic.subTitle);
  });

  test(
    'old serialized entries and blank titles fall back to comic content',
    () {
      final legacy = DiscoverDailyRecommendationEntry.fromJson({
        'comic': {'id': comic.id, 'title': comic.title, 'cover': comic.cover},
      })!;
      expect(legacy.displayTitle, comic.title);
      expect(legacy.displayImageUrl, comic.cover);
      const blank = DiscoverDailyRecommendationEntry(
        comic: comic,
        bannerTitle: '  ',
        imageUrl: '  ',
      );
      expect(blank.displayTitle, comic.title);
      expect(blank.displayImageUrl, comic.cover);
    },
  );
}

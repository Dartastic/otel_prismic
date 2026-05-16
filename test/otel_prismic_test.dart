// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_prismic/otel_prismic.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_prismic-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('query records ref.kind + document_type + lang', () async {
    await tracedPrismic<String>(
      operation: 'documents.query',
      api: 'rest',
      repository: 'repo-1',
      invoke: () async => const PrismicCallResult(
        value: 'ok',
        result: PrismicResult(
          itemCount: 20,
          totalResults: 200,
          totalPages: 10,
          page: 1,
          pageSize: 20,
          documentType: 'article',
          refKind: 'release',
          releaseId: 'rel-1',
          lang: 'en-us',
          cacheHit: false,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('prismic documents.query')!);
    expect(a['prismic.repository'], 'repo-1');
    expect(a['prismic.ref.kind'], 'release');
    expect(a['prismic.release.id'], 'rel-1');
    expect(a['prismic.lang'], 'en-us');
    expect(a['prismic.total_results'], 200);
  });

  test('suppression skips spans', () async {
    await runWithoutPrismicInstrumentationAsync(() async {
      await tracedPrismic<String>(
        operation: 'documents.query',
        invoke: () async => const PrismicCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('prismic '), isEmpty);
  });
}

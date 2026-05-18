// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_prismic_suppression.dart';

const _tracerName = 'dartastic_otel_libs_prismic';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class PrismicResult {
  const PrismicResult({
    this.itemCount,
    this.totalResults,
    this.totalPages,
    this.page,
    this.pageSize,
    this.documentType,
    this.refKind,
    this.releaseId,
    this.lang,
    this.cacheHit,
    this.requestId,
    this.statusCode,
  });

  /// `results.length`.
  final int? itemCount;

  /// `total_results_size`.
  final int? totalResults;

  /// `total_pages`.
  final int? totalPages;

  final int? page;
  final int? pageSize;

  /// `type` predicate / document type.
  final String? documentType;

  /// `master` / `release` / `preview` — Prismic queries always carry a
  /// ref; preview refs bypass the CDN.
  final String? refKind;

  /// Release ID when refKind == release.
  final String? releaseId;

  /// Locale (e.g. `en-us`).
  final String? lang;

  /// CDN cache hit.
  final bool? cacheHit;

  /// `Fastly-Debug-Path` / `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class PrismicCallResult<T> {
  const PrismicCallResult({required this.value, this.result});
  final T value;
  final PrismicResult? result;
}

/// Wraps a Prismic API call in a CLIENT span. [operation] is one of
/// `documents.query`, `documents.getById`, `documents.getByUID`,
/// `documents.getByTag`, `refs.list`, `graphql`, `webhooks.list`.
Future<T> tracedPrismic<T>({
  required String operation,
  required Future<PrismicCallResult<T>> Function() invoke,
  String? api,
  String? repository,
}) async {
  if (prismicInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'prismic',
    'rpc.method': operation,
    'prismic.operation': operation,
  };
  if (api != null) m['prismic.api'] = api;
  if (repository != null) m['prismic.repository'] = repository;

  final span = _tracer().startSpan(
    'prismic $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'prismic.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.totalResults != null) {
        extras.add(OTel.attributeInt(
          'prismic.total_results',
          r.result!.totalResults!,
        ));
      }
      if (r.result!.totalPages != null) {
        extras.add(OTel.attributeInt(
          'prismic.total_pages',
          r.result!.totalPages!,
        ));
      }
      if (r.result!.page != null) {
        extras.add(OTel.attributeInt('prismic.page', r.result!.page!));
      }
      if (r.result!.pageSize != null) {
        extras.add(OTel.attributeInt(
          'prismic.page_size',
          r.result!.pageSize!,
        ));
      }
      if (r.result!.documentType != null) {
        extras.add(OTel.attributeString(
          'prismic.document_type',
          r.result!.documentType!,
        ));
      }
      if (r.result!.refKind != null) {
        extras.add(OTel.attributeString(
          'prismic.ref.kind',
          r.result!.refKind!,
        ));
      }
      if (r.result!.releaseId != null) {
        extras.add(OTel.attributeString(
          'prismic.release.id',
          r.result!.releaseId!,
        ));
      }
      if (r.result!.lang != null) {
        extras.add(OTel.attributeString('prismic.lang', r.result!.lang!));
      }
      if (r.result!.cacheHit != null) {
        extras.add(OTel.attributeBool(
          'prismic.cache.hit',
          r.result!.cacheHit!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'prismic.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Prismic HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

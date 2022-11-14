import 'dart:async';
import 'dart:math';

import 'package:butterfly/bloc/document_bloc.dart';
import 'package:butterfly/cubits/settings.dart';
import 'package:butterfly/cubits/transform.dart';
import 'package:butterfly/dialogs/area/context.dart';
import 'package:butterfly/dialogs/background/context.dart';
import 'package:butterfly/dialogs/elements.dart';
import 'package:butterfly/models/element.dart';
import 'package:butterfly/models/painter.dart';
import 'package:butterfly/renderers/area.dart';
import 'package:butterfly/theme/manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../cubits/current_index.dart';
import '../dialogs/area/label.dart';
import '../helpers/rect_helper.dart';
import '../models/area.dart';
import '../models/cursor.dart';
import '../models/document.dart';
import '../models/pack.dart';
import '../models/path_point.dart';
import '../models/property.dart';
import '../renderers/cursors/eraser.dart';
import '../renderers/renderer.dart';
import '../selections/selection.dart';
import '../services/import.dart';
import '../widgets/context_menu.dart';
import '../widgets/header.dart';

part 'area.dart';
part 'eraser.dart';
part 'hand.dart';
part 'label.dart';
part 'laser.dart';
part 'layer.dart';
part 'path_eraser.dart';
part 'pen.dart';
part 'redo.dart';
part 'shape.dart';
part 'stamp.dart';
part 'undo.dart';

@immutable
class EventContext {
  final BuildContext buildContext;
  final Size viewportSize;
  final bool isShiftPressed, isAltPressed, isCtrlPressed;

  const EventContext(this.buildContext, this.viewportSize, this.isShiftPressed,
      this.isAltPressed, this.isCtrlPressed);

  DocumentBloc getDocumentBloc() => BlocProvider.of<DocumentBloc>(buildContext);
  DocumentLoadSuccess? getState() {
    final state = getDocumentBloc().state;
    if (state is! DocumentLoadSuccess) {
      return null;
    }
    return state;
  }

  void addDocumentEvent(DocumentEvent event) => getDocumentBloc().add(event);
  double get devicePixelRatio => MediaQuery.of(buildContext).devicePixelRatio;

  TransformCubit getTransformCubit() =>
      BlocProvider.of<TransformCubit>(buildContext);

  CameraTransform getCameraTransform() => getTransformCubit().state;

  CurrentIndexCubit getCurrentIndexCubit() =>
      BlocProvider.of<CurrentIndexCubit>(buildContext);

  CurrentIndex getCurrentIndex() => getCurrentIndexCubit().state;

  void refresh() => getDocumentBloc().refresh();

  SettingsCubit getSettingsCubit() =>
      BlocProvider.of<SettingsCubit>(buildContext);
  ButterflySettings getSettings() => getSettingsCubit().state;

  Future<void> bake(
          {Size? viewportSize, double? pixelRatio, bool reset = false}) =>
      getDocumentBloc().bake(
          pixelRatio: pixelRatio, viewportSize: viewportSize, reset: reset);

  List<BlocProvider> getProviders() => [
        BlocProvider<DocumentBloc>.value(value: getDocumentBloc()),
        BlocProvider<TransformCubit>.value(value: getTransformCubit()),
        BlocProvider<CurrentIndexCubit>.value(value: getCurrentIndexCubit()),
        BlocProvider<SettingsCubit>.value(value: getSettingsCubit())
      ];

  Map<Type, Action<Intent>> getActions() =>
      buildContext.findAncestorWidgetOfExactType<Actions>()?.actions ?? {};

  ImportService getImportService() => buildContext.read<ImportService>();
}

enum PainterStatus { normal, disabled }

abstract class Handler<T> {
  final T data;

  const Handler(this.data);

  bool onSelected(DocumentBloc bloc, CurrentIndexCubit currentIndexCubit,
          bool justAdded) =>
      true;

  List<Renderer> createForegrounds(
          CurrentIndexCubit currentIndexCubit, AppDocument document,
          [Area? currentArea]) =>
      [];

  Future<bool> onRendererUpdated(
          AppDocument appDocument, Renderer old, Renderer updated) async =>
      false;

  void onTapUp(TapUpDetails details, EventContext context) {}

  void onTapDown(TapDownDetails details, EventContext context) {}

  void onSecondaryTapUp(TapUpDetails details, EventContext context) {}

  void onSecondaryTapDown(TapDownDetails details, EventContext context) {}

  void onPointerDown(PointerDownEvent event, EventContext context) {}

  void onPointerMove(PointerMoveEvent event, EventContext context) {}

  void onPointerGestureMove(PointerMoveEvent event, EventContext context) {}

  void onPointerUp(PointerUpEvent event, EventContext context) {}

  void onPointerHover(PointerHoverEvent event, EventContext context) {}

  void onLongPressEnd(LongPressEndDetails details, EventContext context) {}

  void onScaleStart(ScaleStartDetails details, EventContext context) {}

  void onScaleUpdate(ScaleUpdateDetails details, EventContext context) {}

  void onScaleEnd(ScaleEndDetails details, EventContext context) {}

  void onDoubleTapDown(TapDownDetails details, EventContext context) {}

  void onDoubleTap(EventContext eventContext) {}

  void onLongPressDown(
      LongPressDownDetails details, EventContext eventContext) {}

  bool canChange(PointerDownEvent event, EventContext eventContext) => true;

  int? getColor(DocumentBloc bloc) => null;

  T? setColor(DocumentBloc bloc, int color) => null;

  void resetInput(DocumentBloc bloc) {}

  PainterStatus getStatus(DocumentBloc bloc) => PainterStatus.normal;

  static Handler fromDocument(AppDocument document, int index) {
    final painter = document.painters[index];
    return Handler.fromPainter(painter);
  }

  static Handler fromPainter(Painter painter) {
    if (painter is HandPainter) {
      return HandHandler(painter);
    }
    if (painter is PenPainter) {
      return PenHandler(painter);
    }
    if (painter is ShapePainter) {
      return ShapeHandler(painter);
    }
    if (painter is EraserPainter) {
      return EraserHandler(painter);
    }
    if (painter is LabelPainter) {
      return LabelHandler(painter);
    }
    if (painter is AreaPainter) {
      return AreaHandler(painter);
    }
    if (painter is PathEraserPainter) {
      return PathEraserHandler(painter);
    }
    if (painter is LayerPainter) {
      return LayerHandler(painter);
    }
    if (painter is LaserPainter) {
      return LaserHandler(painter);
    }
    if (painter is RedoPainter) {
      return RedoHandler(painter);
    }
    if (painter is UndoPainter) {
      return UndoHandler(painter);
    }
    if (painter is StampPainter) {
      return StampHandler(painter);
    }
    throw Exception('Unknown painter type: ${painter.runtimeType}');
  }
}

typedef HitRequest = bool Function(Offset position, [double radius]);

class _SmallRenderer {
  final HitCalculator hitCalc;
  final PadElement element;

  _SmallRenderer(this.hitCalc, this.element);
  _SmallRenderer.fromRenderer(Renderer renderer)
      : hitCalc = renderer.getHitCalculator(),
        element = renderer.element;
}

class _RayCastParams {
  final List<String> invisibleLayers;
  final List<_SmallRenderer> renderers;
  final Rect rect;
  final double size;
  final bool includeEraser;

  const _RayCastParams(this.invisibleLayers, this.renderers, this.rect,
      this.size, this.includeEraser);
}

Future<Set<Renderer<PadElement>>> rayCast(
    Offset globalPosition, BuildContext context, double radius,
    [bool includeEraser = false]) async {
  return rayCastRect(Rect.fromCircle(center: globalPosition, radius: radius),
      context, includeEraser);
}

Future<Set<Renderer<PadElement>>> rayCastRect(Rect rect, BuildContext context,
    [bool includeEraser = false]) async {
  final bloc = context.read<DocumentBloc>();
  final transform = context.read<TransformCubit>().state;
  final state = bloc.state;
  if (state is! DocumentLoadSuccess) return {};
  final renderers = state.cameraViewport.visibleElements;
  rect = rect.normalized();
  return compute(
          _executeRayCast,
          _RayCastParams(
              state.invisibleLayers,
              renderers.map((e) => _SmallRenderer.fromRenderer(e)).toList(),
              rect,
              transform.size,
              includeEraser))
      .then((value) => value.map((e) => renderers[e]).toSet());
}

Set<int> _executeRayCast(_RayCastParams params) {
  return params.renderers
      .asMap()
      .entries
      .where((e) => !params.invisibleLayers.contains(e.value.element.layer))
      .where((e) => e.value.hitCalc.hit(params.rect))
      .where((e) => params.includeEraser || e.value.element is! EraserElement)
      .map((e) => e.key)
      .toSet();
}

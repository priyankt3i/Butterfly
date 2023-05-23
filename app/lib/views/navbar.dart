import 'package:butterfly/bloc/document_bloc.dart';
import 'package:butterfly/cubits/current_index.dart';
import 'package:butterfly/cubits/settings.dart';
import 'package:butterfly/views/files.dart';
import 'package:butterfly_api/butterfly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:material_leap/material_leap.dart';

class DocumentNavbar extends StatefulWidget {
  final bool asDrawer;
  const DocumentNavbar({super.key, this.asDrawer = false});

  @override
  State<DocumentNavbar> createState() => _DocumentNavbarState();
}

class _DocumentNavbarState extends State<DocumentNavbar>
    with SingleTickerProviderStateMixin {
  RemoteStorage? _remote;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 0,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _remote = context.read<SettingsCubit>().getRemote();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrentIndexCubit, CurrentIndex>(
      buildWhen: (previous, current) =>
          previous.cameraViewport.tool.element.navbarEnabled !=
          current.cameraViewport.tool.element.navbarEnabled,
      builder: (context, currentIndex) {
        Widget content;
        if (!currentIndex.cameraViewport.tool.element.navbarEnabled &&
            !widget.asDrawer) {
          content = const SizedBox.shrink();
          _controller.reverse(from: 1);
        } else {
          _controller.forward(from: 0);
          content = Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                Header(
                  title: Text(AppLocalizations.of(context).files),
                  actions: [
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          if (widget.asDrawer) {
                            Navigator.of(context).pop();
                            return;
                          }
                          final state = context.read<DocumentBloc>().state;
                          if (state is! DocumentLoaded) return;
                          final document = state.data;
                          final page = state.page;
                          final toolState = context
                              .read<CurrentIndexCubit>()
                              .state
                              .cameraViewport
                              .tool
                              .element;
                          context.read<CurrentIndexCubit>().updateTool(
                                document,
                                page,
                                toolState.copyWith(navbarEnabled: false),
                              );
                        }),
                  ],
                ),
                BlocBuilder<DocumentBloc, DocumentState>(
                    buildWhen: (previous, current) =>
                        previous is! DocumentLoaded ||
                        current is! DocumentLoaded ||
                        current.location != previous.location,
                    builder: (context, state) {
                      AssetLocation? location;
                      if (state is DocumentLoaded) {
                        location = state.location;
                      }
                      return FilesView(
                        remote: _remote,
                        selectedAsset: location,
                        collapsed: true,
                      );
                    }),
              ],
            ),
          );
        }
        if (widget.asDrawer) {
          return Drawer(
            width: 400,
            child: content,
          );
        } else {
          return AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              if (_animation.value == 0) return const SizedBox.shrink();
              return SizedBox(
                width: 400 * _animation.value,
                child: ClipRect(
                  child: Transform.translate(
                    offset: Offset(-400 * (1 - _animation.value), 0),
                    child: OverflowBox(
                        maxWidth: double.infinity,
                        child: SizedBox(width: 400, child: child)),
                  ),
                ),
              );
            },
            child: content,
          );
        }
      },
    );
  }
}

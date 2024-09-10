import 'package:butterfly/bloc/document_bloc.dart';
import 'package:butterfly/dialogs/delete.dart';
import 'package:butterfly/dialogs/name.dart';
import 'package:butterfly/handlers/handler.dart';
import 'package:butterfly_api/butterfly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:material_leap/material_leap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CollectionsDialog extends StatefulWidget {
  const CollectionsDialog({super.key});

  @override
  State<CollectionsDialog> createState() => _CollectionsDialogState();
}

class _CollectionsDialogState extends State<CollectionsDialog> {
  String _collection = '';

  @override
  Widget build(BuildContext context) {
    return ResponsiveAlertDialog(
      title: Text(AppLocalizations.of(context).collections),
      constraints: const BoxConstraints(maxWidth: LeapBreakpoints.compact),
      content:
          BlocBuilder<DocumentBloc, DocumentState>(builder: (context, state) {
        final collections =
            {'', ...?state.page?.content.map((e) => e.collection)}.toList();
        return ListView.separated(
          shrinkWrap: true,
          itemCount: collections.length,
          separatorBuilder: (context, index) =>
              index == 0 ? const Divider() : const SizedBox(),
          itemBuilder: (context, index) {
            final collection = collections[index];
            return ListTile(
              title: Text(collection.isEmpty
                  ? AppLocalizations.of(context).defaultCollection
                  : collection),
              selected: collection == _collection,
              onTap: () {
                setState(() {
                  _collection = collection;
                });
              },
            );
          },
        );
      }),
      leading: IconButton.outlined(
        icon: const Icon(PhosphorIconsLight.x),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () async {
            final bloc = context.read<DocumentBloc>();
            Navigator.pop(context);
            final cubit = bloc.state.currentIndexCubit;
            if (cubit == null) return;
            final handler = cubit.fetchHandler<SelectHandler>() ??
                await cubit.changeTemporaryHandler(
                  context,
                  SelectTool(),
                  bloc: bloc,
                  temporaryClicked: true,
                );
            if (handler is! SelectHandler) return;
            handler.selectAll(bloc, (e) => e.element.collection == _collection);
          },
          label: Text(AppLocalizations.of(context).select),
          icon: const PhosphorIcon(PhosphorIconsLight.selection),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final bloc = context.read<DocumentBloc>();
            final name = await showDialog<String>(
              context: context,
              builder: (context) => NameDialog(
                value: _collection,
              ),
            );
            if (name == null) return;
            bloc.add(LayerRenamed(_collection, name));
            setState(() => _collection = name);
          },
          icon: const PhosphorIcon(PhosphorIconsLight.textT),
          label: Text(AppLocalizations.of(context).rename),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final bloc = context.read<DocumentBloc>();
            final result = await showDialog<bool>(
                context: context, builder: (context) => const DeleteDialog());
            if (result != true) return;
            bloc.add(LayerElementsRemoved(_collection));
            if (context.mounted) Navigator.pop(context);
            setState(() => _collection = '');
          },
          label: Text(AppLocalizations.of(context).deleteElements),
          icon: const PhosphorIcon(PhosphorIconsLight.trash),
        ),
      ],
    );
  }
}

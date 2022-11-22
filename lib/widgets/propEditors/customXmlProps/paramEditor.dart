
import 'package:flutter/material.dart';

import '../../../background/IdLookup.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/openFilesManager.dart';
import '../../../utils/utils.dart';
import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/XmlPropEditor.dart';
import '../simpleProps/propEditorFactory.dart';

class ParamsEditor extends StatelessWidget {
  final bool showDetails;
  final XmlProp prop;

  const ParamsEditor({super.key, required this.prop, required this.showDetails});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).formElementBgColor,
          border: Border.all(color: getTheme(context).propBorderColor!, width: 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(10))
        ),
        padding: const EdgeInsets.only(right: 15),
        child: IntrinsicWidth(
          child: Wrap(
            direction: Axis.horizontal,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              makePropEditor(prop[0].value),
              if (showDetails || (prop[1].value as HexProp).strVal == "type")
                makePropEditor(prop[1].value),
              if (prop[2].isEmpty)
                makePropEditor(prop[2].value)
              else
                XmlPropEditor(prop: prop[2], showDetails: false, showTagName: false,),
              ChangeNotifierBuilder(
                notifier: prop[0].value,
                builder: (context) {
                  var code = prop[0].value;
                  if (code is! StringProp || code.value != "NameTag")
                    return const SizedBox();
                  return IconButton(
                    onPressed: () async {
                      const int charNamesId = 0x75445849;
                      var charNamesLookup = await idLookup.lookupId(charNamesId);
                      if (charNamesLookup.isEmpty) {
                        showToast("CharNames from corehap.dat not found! Check indexing settings.", const Duration(seconds: 6));
                        return;
                      }
                      var charNamesResult = charNamesLookup[0];
                      areasManager.openFile(charNamesResult.xmlPath);
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 10),
                    iconSize: 15,
                    splashRadius: 15,
                    icon: const Icon(Icons.edit),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

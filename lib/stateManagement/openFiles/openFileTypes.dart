
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../utils/Disposable.dart';
import '../../widgets/filesView/FileType.dart';
import '../hasUuid.dart';
import '../miscValues.dart';
import '../undoable.dart';
import 'types/BnkFilePlaylistData.dart';
import 'types/EstFileData.dart';
import 'types/FtbFileData.dart';
import 'types/McdFileData.dart';
import 'types/RubyFileData.dart';
import 'types/SaveSlotData.dart';
import 'types/SmdFileData.dart';
import 'types/TextFileData.dart';
import 'types/TmdFileData.dart';
import 'types/WaiFileData.dart';
import 'types/WemFileData.dart';
import 'types/WtaWtpData.dart';
import 'types/XmlFileData.dart';

enum LoadingState {
  notLoaded,
  loading,
  loaded,
}

abstract class OptionalFileInfo {
  const OptionalFileInfo();
}

abstract class OpenFileData with HasUuid, Undoable implements Disposable {
  OptionalFileInfo? optionalInfo;
  final IconData? icon;
  final Color? iconColor;
  late final FileType type;
  final ValueNotifier<String> name;
  final ValueNotifier<String?> secondaryName;
  final String path;
  final ValueNotifier<bool> _hasUnsavedChanges = ValueNotifier(false);
  ValueListenable<bool> get hasUnsavedChanges => _hasUnsavedChanges;
  final ValueNotifier<LoadingState> loadingState = ValueNotifier(LoadingState.notLoaded);
  bool keepOpenAsHidden = false;
  final ChangeNotifier contentNotifier = ChangeNotifier();
  final ScrollController scrollController = ScrollController();
  bool canBeReloaded = true;

  OpenFileData(String name, this.path, { required this.type, String? secondaryName, this.icon, this.iconColor }) :
    name = ValueNotifier(name),
    secondaryName = ValueNotifier(secondaryName);

  factory OpenFileData.from(String name, String path, { String? secondaryName, OptionalFileInfo? optionalInfo }) {
    if (path.endsWith(".xml"))
      return XmlFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".rb"))
      return RubyFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".tmd"))
      return TmdFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".smd"))
      return SmdFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".mcd"))
      return McdFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".ftb"))
      return FtbFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".wem"))
      return WemFileData(name, path, secondaryName: secondaryName, wemInfo: optionalInfo as OptionalWemData?);
    else if (path.endsWith(".wai"))
      return WaiFileData(name, path, secondaryName: secondaryName);
    else if (RegExp(r"\.bnk#p=\d+").hasMatch(path))
      return BnkFilePlaylistData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".dat") && basename(path).startsWith("SlotData_"))
      return SaveSlotData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".wta") || path.endsWith(".wtb"))
      return WtaWtpData(name, path, secondaryName: secondaryName, isWtb: path.endsWith(".wtb"));
    else if (path.endsWith(".est") || path.endsWith(".sst"))
      return EstFileData(name, path, secondaryName: secondaryName);
    else
      return TextFileData(name, path, secondaryName: secondaryName);
  }

  String get displayName => secondaryName.value == null ? name.value : "${name.value} - ${secondaryName.value}";

  setHasUnsavedChanges(bool value) {
    if (value == _hasUnsavedChanges.value)
      return;
    if (disableFileChanges)
      return;
    _hasUnsavedChanges.value = value;
  }

  Future<void> load() async {
    loadingState.value = LoadingState.loaded;
    setHasUnsavedChanges(false);
    undoHistoryManager.onUndoableEvent();
  }

  Future<void> reload() async {
    if (!canBeReloaded) return;
    loadingState.value = LoadingState.notLoaded;
    await load();
  }

  Future<void> save() async {
    setHasUnsavedChanges(false);
  }

  @override
  void dispose() {
    name.dispose();
    secondaryName.dispose();
    _hasUnsavedChanges.dispose();
    contentNotifier.dispose();
    scrollController.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../main.dart';
import '../widgets/misc/confirmCancelDialog.dart';
import 'nestedNotifier.dart';
import 'openFileTypes.dart';
import 'undoable.dart';

class FilesAreaManager extends NestedNotifier<OpenFileData> implements Undoable {
  OpenFileData? _currentFile;

  FilesAreaManager() : super([]);

  OpenFileData? get currentFile => _currentFile;
  
  set currentFile(OpenFileData? value) {
    assert(value == null || contains(value));
    if (value == _currentFile) return;
    _currentFile = value;
    notifyListeners();
  }

  void switchToClosestFile() {
    if (length <= 1) {
      currentFile = null;
      return;
    }

    var index = indexOf(currentFile!);
    if (index + 1 == length)
      index--;
    else
      index++;
    currentFile = this[index];
  }

  Future<void> closeFile(OpenFileData file) async {
    if (file.hasUnsavedChanges) {
      var answer = await confirmOrCancelDialog(
        getGlobalContext(),
        title: "Save changes?",
        body: "${file.name} has unsaved changes",
      );
      if (answer == true)
        await file.save();
      else if (answer == null)
        return;
    }

    if (currentFile == file)
      switchToClosestFile();
    remove(file);

    if (length == 0 && areasManager.length > 1)
      areasManager.remove(this);
    
    undoHistoryManager.onUndoableEvent();
  }

  void closeAll() {
    var listCopy = List.from(this);
    for (var file in listCopy)
      closeFile(file);
  }

  void closeOthers(OpenFileData file) {
    var listCopy = List.from(this);
    for (var otherFile in listCopy)
      if (otherFile != file)
        closeFile(otherFile);
  }

  void closeToTheLeft(OpenFileData file) {
    var listCopy = List.from(this);
    int index = listCopy.indexOf(file);
    for (int i = 0; i < index; i++)
      closeFile(listCopy[i]);
  }

  void closeToTheRight(OpenFileData file) {
    var listCopy = List.from(this);
    int index = listCopy.indexOf(file);
    for (int i = index + 1; i < listCopy.length; i++)
      closeFile(listCopy[i]);
  }

  void moveToRightView(OpenFileData file) {
    if (currentFile == file)
      switchToClosestFile();
      
    int areaIndex = areasManager.indexOf(this);
    FilesAreaManager rightArea;
    if (areaIndex >= areasManager.length - 1) {
      rightArea = FilesAreaManager();
      areasManager.add(rightArea);
    }
    else {
      rightArea = areasManager[areaIndex + 1];
    }
    remove(file);
    rightArea.add(file);
    rightArea.currentFile = file;
    
    if (length == 0) {
      areasManager.remove(this);
    }

    undoHistoryManager.onUndoableEvent();
  }

  void moveToLeftView(OpenFileData file) {
    if (currentFile == file)
      switchToClosestFile();
    
    int areaIndex = areasManager.indexOf(this);
    int leftAreaIndex = areaIndex - 1;
    FilesAreaManager leftArea;
    if (leftAreaIndex < 0 || leftAreaIndex >= areasManager.length) {
      leftArea = FilesAreaManager();
      areasManager.insert(leftAreaIndex, leftArea);
    }
    else {
      leftArea = areasManager[leftAreaIndex];
    }
    remove(file);
    leftArea.add(file);
    leftArea.currentFile = file;
    
    if (length == 0) {
      areasManager.remove(this);
    }
    
    undoHistoryManager.onUndoableEvent();
  }

  void switchToNextFile() {
    if (length <= 1) return;
    int nextIndex = (indexOf(currentFile!) + 1) % length;
    currentFile = this[nextIndex];
  }

  void switchToPreviousFile() {
    if (length <= 1) return;
    int nextIndex = (indexOf(currentFile!) - 1) % length;
    if (nextIndex < 0)
      nextIndex += length;
    currentFile = this[nextIndex];
  }
  
  Future<void> saveAll() async {
    await Future.wait(
      where((file) => file.hasUnsavedChanges)
      .map((file) => file.save()));
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = FilesAreaManager();
    snapshot.overrideUuidForUndoable(uuid);
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as OpenFileData).toList());
    snapshot._currentFile = _currentFile != null ? _currentFile!.takeSnapshot() as OpenFileData : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as FilesAreaManager;
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as OpenFileData);
    if (entry._currentFile != null)
      currentFile = where((file) => file.uuid == entry._currentFile!.uuid).first;
    else
      currentFile = null;
  }
}

class OpenFilesAreasManager extends NestedNotifier<FilesAreaManager> {
  FilesAreaManager? _activeArea;
  final ChangeNotifier subEvents = ChangeNotifier();
  final ChangeNotifier onSaveAll = ChangeNotifier();

  OpenFilesAreasManager() : super([]) {
    addListener(subEvents.notifyListeners);
  }

  bool isFileOpened(String path) {
    for (var area in this) {
      for (var file in area) {
        if (file.path == path)
          return true;
      }
    }
    return false;
  }

  OpenFileData? getFile(String path) {
    for (var area in this) {
      for (var file in area) {
        if (file.path == path)
          return file;
      }
    }
    return null;
  }

  FilesAreaManager? getAreaOfFile(OpenFileData searchFile) {
    for (var area in this) {
      if (area.contains(searchFile))
        return area;
    }
    return null;
  }

  FilesAreaManager? get activeArea => _activeArea;

  set activeArea(FilesAreaManager? value) {
    assert(value == null || contains(value));
    if (value == _activeArea)
      return;
    _activeArea = value;
    notifyListeners();
  }

  OpenFileData openFile(String filePath, { FilesAreaManager? toArea, bool focusIfOpen = true }) {
    if (isFileOpened(filePath)) {
      var openFile = getFile(filePath)!;
      if (focusIfOpen)
        getAreaOfFile(openFile)!.currentFile = openFile;
      return openFile;
    }

    toArea ??= activeArea ?? this[0];
    OpenFileData file = OpenFileData.from(path.basename(filePath), filePath);
    toArea.add(file);
    toArea.currentFile = file;

    undoHistoryManager.onUndoableEvent();

    return file;
  }

  @override
  void add(FilesAreaManager child) {
    super.add(child);
    activeArea ??= child;
    child.addListener(subEvents.notifyListeners);
  }

  @override
  void remove(child) {
    if (child == _activeArea)
      _activeArea = this[0];
    child.removeListener(subEvents.notifyListeners);
    super.remove(child);
  }

  @override
  void removeAt(int index) {
    if (this[index] == _activeArea)
      _activeArea = this[0];
    this[index].removeListener(subEvents.notifyListeners);
    super.removeAt(index);
  }

  @override
  void clear() {
    _activeArea = null;
    super.clear();
  }
  
  Future<void> saveAll() async {
    await Future.wait(map((area) => area.saveAll()));
    onSaveAll.notifyListeners();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = OpenFilesAreasManager();
    snapshot.replaceWith(map((area) => area.takeSnapshot() as FilesAreaManager).toList());
    snapshot._activeArea = _activeArea != null ? _activeArea!.takeSnapshot() as FilesAreaManager : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as OpenFilesAreasManager;
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as FilesAreaManager);
    if (entry._activeArea != null)
      activeArea = where((area) => area.uuid == entry._activeArea!.uuid).first;
    else
      activeArea = null;
  }
}

final areasManager = OpenFilesAreasManager();

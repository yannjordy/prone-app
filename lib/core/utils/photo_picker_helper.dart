import 'photo_picker_helper_stub.dart'
    if (dart.library.html) 'photo_picker_helper_web.dart' as impl;

abstract class PhotoPickerHelper {
  Future<List<int>?> pickImage();
  static PhotoPickerHelper instance = impl.PhotoPickerHelperImpl();
}

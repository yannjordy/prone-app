import 'photo_picker_helper_stub.dart'
    if (dart.library.html) 'photo_picker_helper_web.dart' as impl;

class PhotoPickerHelper {
  Future<List<int>?> pickImage() async {
    return await impl.PhotoPickerHelperImpl().pickImage();
  }
}

import 'package:image_picker/image_picker.dart';
import 'photo_picker_helper.dart';

class PhotoPickerHelperImpl implements PhotoPickerHelper {
  @override
  Future<List<int>?> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 80);
    if (picked == null) return null;
    return await picked.readAsBytes();
  }
}

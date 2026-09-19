import 'dart:typed_data';
import 'dart:html' as html;
import 'photo_picker_helper.dart';

class PhotoPickerHelperImpl implements PhotoPickerHelper {
  @override
  Future<List<int>?> pickImage() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return null;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    return Uint8List.fromList(reader.result as List<int>);
  }
}

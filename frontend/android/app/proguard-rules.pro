# google_mlkit_text_recognition references every script's *TextRecognizerOptions,
# but we only depend on the Latin recognizer (TextRecognizer() with no script arg
# in add_edit_product_page.dart). R8 fails the release build on the absent classes
# unless they're explicitly ignored.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

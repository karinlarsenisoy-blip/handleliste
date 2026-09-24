# google_mlkit_text_recognition's base module references these optional
# per-script recognizer classes (Chinese/Devanagari/Japanese/Korean) even
# though we only ever use the default (Latin) recognizer — we don't depend
# on the separate packages that provide them, so R8 can't find them during
# release minification. They're genuinely never called at runtime here, so
# it's safe to tell R8 not to worry about them, per Google's own guidance:
# https://developers.google.com/ml-kit/vision/text-recognition/v2/android#4-process-the-image
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

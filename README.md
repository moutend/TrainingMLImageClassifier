# Training MLImageClassifier

This is a sample app for training and inference of an image classification model on iPhone using MLImageClassifier.

The app estimates the cardinal directions (north, south, east and west) from photos. It could function with indoor photos, but in cases like rooms surrounded by walls of the same color, it might not be able to learn features from the photos, thus failing to accurately determine directions.

## System Requirements

- iOS 15.0+
- Xcode 14.2+

## How to Use the App

When you launch the app, you will see "Classify" and "Train" buttons. First, select "Train" to train the model.

On the next screen, you will be presented with a screen to create training data for each of the cardinal directions. When you press the button, the camera preview screen will be displayed.

While capturing training data, please hold your iPhone portrait mode. Slightly tilt it back and forth or move your hand slightly to create a more better model.

Once you have created training data for all directions, press the "Next" button. Depending on the performance of your device and the content of the training data, it will take about 30 seconds to complete the training on an iPhone 13, for example.

After the training is complete, return to the initial screen and press the "Classify" button. On the next screen, press the "Compile Image Classifier" button to compile the model you just created. On an iPhone 13, compilation takes about 30 ms.

Once the model is compiled, you can try classifying images. Image classification is performed every second, and the results are displayed at the bottom of the screen.

## License

MIT

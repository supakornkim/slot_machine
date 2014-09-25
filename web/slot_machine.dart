import 'dart:html';
import 'dart:async';
import 'dart:math';

void main() {
  var container = querySelector("#slot_container");
  
  querySelector("#sample_text_id").onClick.listen((_) {
    container.children.clear();

    var slotMachine = new SlotMachineAnimation([0.6, 0.4, 0.5, 1.0, 0.1]);
    container.append(slotMachine.canvasEl);
    container.append(slotMachine.resultEl);
    slotMachine.roll()
    .then(print);
  });
}


class SlotMachineAnimation {
  SlotMachineAnimation(List<num> linesProbabilities, 
      {this.slotLines: 5, this.width: 40}) {
    assert(linesProbabilities.length == slotLines);
    height = width;
    
    canvasEl = new CanvasElement(width: width * slotLines, height: width * 3);
    _ctx = canvasEl.context2D;
    resultEl = new SpanElement();
    
    _lines = new List<_SlotMachineLine>(slotLines);
    for (int i = 0; i < slotLines; i += 1) {
      _lines[i] = new _SlotMachineLine(linesProbabilities[i], _ctx, i * width,
          width, height);
    }
    currentResults = new List<bool>(slotLines);
    
    if (slotLines % 2 == 0) {
      throw new ArgumentError("Slots need to be an odd number.");
    }
    
    // Prepare gradient
    _gradient = _ctx.createLinearGradient(0, 0, 0, canvasEl.height);
    _gradient.addColorStop(0, 'rgba(255,255,255,1)');
    _gradient.addColorStop(0.2, 'rgba(255,255,255,0)');
    _gradient.addColorStop(0.8, 'rgba(255,255,255,0)');
    _gradient.addColorStop(1, 'rgba(255,255,255,1)');
  }
  final int slotLines;
  final int width;
  int height;

//  final num probability;
  int result;
  
  CanvasElement canvasEl;
  CanvasRenderingContext2D _ctx;
  
  CanvasGradient _gradient;
  
  SpanElement resultEl;
  
  List<_SlotMachineLine> _lines;
  
  Completer<String> _rollCompleter;
  
  Future<String> roll() {
    if (_rollCompleter != null) {
      throw new StateError("Cannot roll one slot machine twice.");
    }
    _rollCompleter = new Completer<String>();
    
    update(0);
    
    return _rollCompleter.future;
  }
  
  num last_t = 0;
  num _timeFromStartOfRoll;
  List<bool> currentResults;
  
  void update(num timeFromStartOfPage) {
    if (_timeFromStartOfRoll == null && timeFromStartOfPage != 0) {
      _timeFromStartOfRoll = timeFromStartOfPage;
    }
    num dt = timeFromStartOfPage - last_t;
    last_t = timeFromStartOfPage;
    
    if (_lines.every((line) => line.isFinished)) {
      resultEl.text = currentResultText;
      _rollCompleter.complete(currentResultText);
      return;
    }
    
    for (int i = 0; i < slotLines; i++) {
      _SlotMachineLine line = _lines[i];
      currentResults[i] = line.currentResult;
      if (_timeFromStartOfRoll != null &&
          last_t - _timeFromStartOfRoll > line.fullSpeedMilliseconds) {
        line.isSlowingDown = true;
      }
      line.update(dt);
    }
    
    // Draw the gradient overlay.
    _ctx.fillStyle = _gradient;
    _ctx.fillRect(0, 0, width * slotLines, height * 3);
    
    resultEl.text = currentResultText;
    
    window.animationFrame.then(update);
  }
  
  static const String CRITICAL_SUCCESS = "critical success";
  static const String SUCCESS = "success";
  static const String FAILURE = "failure";
  static const String CRITICAL_FAILURE = "critical failure";
  
  String get currentResultText {
    if (currentResults.any((result) => result == null)) return "";
    int positives = currentResults
        .fold(0, (int sum, bool result) => sum += result ? 1 : 0);
    int negatives = slotLines - positives;
    if (positives == slotLines) return CRITICAL_SUCCESS;
    if (negatives == slotLines) return CRITICAL_FAILURE;
    if (positives > negatives) return SUCCESS;
    if (positives < negatives) return FAILURE;
    // Slots are always odd.
    throw new StateError("Cannot decide success or fail.");
  }
  
//  void clear() {
////    _ctx.clearRect(0, 0, width * slots, height * 3);
//    _ctx.fillStyle = '#ffffff';
//    _ctx.fillRect(0, 0, width * slots, height * 3);
//    
////    _ctx.rect(0, 0, width * slots, height * 3);
////    _ctx.fillStyle = 'white';
////    _ctx.fill();
//  }
  
  static const int CRITICAL_HIT = 2;
  static const int HIT = 1;
  static const int FAIL = -1;
  static const int CRITICAL_FAIL = -2;
  
  // TODO: completedWithHit, completedWithFail ... getters
  
}

class _SlotMachineLine {
  static const int SLOT_COUNT = 10;
  static final Random _random = new Random();
  
  final num probability;
  final int leftOffset; 
  final int width;
  final int height;
  num fullSpeedMilliseconds;
  final CanvasRenderingContext2D _ctx;
  
  _SlotMachineLine(this.probability, this._ctx, this.leftOffset,
      this.width, this.height) {
    _values = new List<bool>.filled(SLOT_COUNT, false);
    
    int successValuesTarget = (SLOT_COUNT * probability).round();
    int successValuesCurrent = 0;
    while (successValuesCurrent < successValuesTarget) {
      int index = _random.nextInt(SLOT_COUNT);
      if (_values[index] == false) {
        _values[index] = true;
        successValuesCurrent += 1;
      }
    }
   
    fullSpeedMilliseconds = _random.nextInt(2000);
    
    // Fail otherwise, because our assets are 40x40.
    assert(width == 40);
    assert(height == 40);
  }
  
  num topOffset = 0;
  num speed = 0.01;
  num drag = 0.0001;
  bool isSlowingDown = false;
  bool isFinished = false;
  
  final CanvasImageSource successSource= 
      new ImageElement(src: "img/slot-success.gif", width: 40, height: 40);
  final CanvasImageSource failureSource = 
      new ImageElement(src: "img/slot-failure.gif", width: 40, height: 40);
  
  num _pos = 0;
  
  bool currentResult;
  
  List<bool> _values;
  
  void drawSquare(num topOffset, bool value) {
//    _ctx.fillStyle = value ? 'green' : 'red';
    //    ctx.setFillColorRgb(255, 0, 0);
//    _ctx.fillRect(leftOffset, topOffset, width, height);
    
    _ctx.drawImage(value ? successSource : failureSource, 
        leftOffset, topOffset);
  }
  
  void update(num dt) {
    if (isSlowingDown && !isFinished) {
      if (speed <= 0.001) {
        if ((_pos % height).abs() < height / 20) {
          speed = 0;
          isFinished = true;
        }
      } else {
        speed -= drag;
      }
    }
    
    clear();
    
    if (!isFinished) {
      _pos += (dt * speed * height);
    }
    num normalizedPos = _pos % (height * SLOT_COUNT);
    
    int topIndex = (normalizedPos / height).floor();
    currentResult = _values[(topIndex - 2) % SLOT_COUNT];
    for (int i = 0; i < 3 + 1; i++) {
      int index = topIndex - i; 
      drawSquare((normalizedPos % height) - height + (height * i), 
          _values[index % SLOT_COUNT]);
    }
    
  }
  
  void clear() {
    _ctx.fillStyle = '#ffffff';
    _ctx.fillRect(leftOffset, 0, width, height * 3);
  }
}

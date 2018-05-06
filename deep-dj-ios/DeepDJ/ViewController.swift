//
//  ViewController.swift
//  DeepDJ
//
//  Created by Andrew Aquino on 5/5/18.
//  Copyright © 2018 Andrew Aquino. All rights reserved.
//

import UIKit
import AWSDynamoDB
import ReactiveSwift
import Result
import SwiftCharts
import PieCharts
import Cartography

typealias Emotion = (timestamp: Int, value: Double)
typealias Emotions = (happy: Emotion, calm: Emotion, sad: Emotion)

class ViewController: UIViewController, PieChartDelegate {

  let db = AWSDynamoDBObjectMapper.default()
  
  let happiness = MutableProperty<[Emotion]>([])
  let calmness = MutableProperty<[Emotion]>([])
  let sadness = MutableProperty<[Emotion]>([])
  
  let timestampLabel = UILabel()
  
  fileprivate var chart: Chart? // arc
  var chartView: PieChart!

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    timestampLabel.textColor = UIColor.black.withAlphaComponent(0.8)
    timestampLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
    timestampLabel.textAlignment = .center
    timestampLabel.numberOfLines = 0
    view.addSubview(timestampLabel)
    constrain(timestampLabel, view) { timestampLabel, superview in
      timestampLabel.top == superview.top + 64
      timestampLabel.left == superview.left + 10
      timestampLabel.right == superview.right - 10
    }

    view.backgroundColor = .white
    
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      self.updateData()
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  var previousValue: Int = 0
  
  func updateData() {
    getFaces().flatMap(.latest, mapEmotions).flatMapError { _ in .empty }.startWithValues { emotions in
      
      var happiness = emotions.map { $0.happy }
      var calmness = emotions.map { $0.calm }
      var sadness = emotions.map { $0.sad }
      
      //      happiness = self.convertToAverage(array: happiness.map { $0.value }).enumerated().map { (happiness[$0].timestamp, $1) }
      //      calmness = self.convertToAverage(array: calmness.map { $0.value }).enumerated().map { (calmness[$0].timestamp, $1) }
      //      sadness = self.convertToAverage(array: sadness.map { $0.value }).enumerated().map { (sadness[$0].timestamp, $1) }
      
      
      //      self.happiness.value = happiness
      //      self.calmness.value = calmness
      //      self.sadness.value = sadness
      let x = (happiness.map { $0.value } + calmness.map { $0.value } + sadness.map { $0.value }).reduce(0, +)
      let currentValue = Int(x)
      guard currentValue != self.previousValue else { return }
      self.previousValue = currentValue
      print(currentValue)

      self.chartView?.removeFromSuperview()
      self.chartView = PieChart(frame: UIScreen.main.bounds)
//      self.chartView.animDuration = 0
      self.view.addSubview(self.chartView)
      
      self.chartView.layers = [self.createCustomViewsLayer(), self.createTextLayer()]
      self.chartView.delegate = self
      self.chartView.models = self.createPieModel(happiness: happiness, calmness: calmness, sadness: sadness)
      
//      let avg = sentiment.reduce(0.0, +) / Double(sentiment.count)
    }
    //    let data: SignalProducer<[Emotion], NoError> = getData().flatMap(.latest, applyAlgorithm).flatMapError { _ in .empty }
    //    happy <~ data.map { $0.happy }
    //    calm <~ data.map { $0.calm }
    //    sad <~ data.map { $0.sad }
  }
  
  func getFaces() -> SignalProducer<[Face], AWSError> {
    print("scanning database")
    return SignalProducer { observer, _ in
      let query = AWSDynamoDBScanExpression()
      query.limit = 50
      self.db.scan(Face.self, expression: query).continueWith(executor: .mainThread()) { task in
        if let error = task.error {
          print(error)
          observer.send(error: .error(error))
        } else if let faces = task.result?.items.compactMap({ $0 as? Face }) {
          observer.send(value: faces)
        }
        return nil
      }
    }
  }
  
  func mapEmotions(_ faces: [Face]) -> SignalProducer<[Emotions], AWSError> {
    return SignalProducer { observer, _ in
//      let count = faces.count
//      let (happy, calm, sad) = faces
      let emotions: [Emotions] = faces
        // most recent first
        .sorted(by: { $0.timestamp < $1.timestamp })
        // linear decreasing weight
        .enumerated().map { index, face -> Emotions in
          let minutes = Calendar.current.component(.minute, from: face.createdAt)
//          let seconds = Calendar.current.component(.second, from: face.createdAt)

//          let weight = Double(count - index) / Double(count)
          let happy: Emotion = (minutes, face.happy.doubleValue / 100)
          let calm: Emotion = (minutes, face.calm.doubleValue / 100)
          let sad: Emotion = (minutes, face.sad.doubleValue / 100)
          return (happy, calm, sad)
        }
      
      if let createdAt = faces.last?.createdAt {
        self.timestampLabel.text = "most recent:\n\(createdAt)"
      }

      observer.send(value: emotions)
        // map reduce
//        .reduce((0.0, 0.0, 0.0), { result, item in
//          let (rH, rC, rS) = result
//          let (iH, iC, iS) = item
//          let happy = rH >= 0 ? rH + iH : 0
//          let calm = rC >= 0 ? rC + iC : 0
//          let sad = rS >= 0 ? rS + iS : 0
//          return (happy, calm, sad)
//        })
//      let divisor = Double(count)
//      let emotion = (happy / divisor, calm / divisor, sad / divisor)
//      observer.send(value: emotion)
    }
  }
  
  func convertToAverage(array: [Double]) -> [Double] {
    var hAvg: Double = 0
    var hAvgs: [Double] = []
    for (index, value) in array.enumerated() {
      if index == 0 {
        hAvg = value
      } else {
        hAvg = (value + hAvgs.reduce(0.0, { $0 + $1 })) / Double(index + 1)
      }
      hAvgs.append(hAvg)
    }
    return hAvgs
  }

  func createGraph(happiness: [Emotion], calmness: [Emotion], sadness: [Emotion]) {
    
//    let hCount = happiness.count
//    let x = happiness.enumerated().reduce(0.0) { result, params in
//      let (index, emotion) = params
//      let weight = Double(hCount - index) / Double(hCount)
//      return result + (emotion.value * weight)
//    }

    let labelSettings = ChartLabelSettings(font: UIFont.systemFont(ofSize: 12, weight: .regular))

    let chartPoints = happiness.map{ChartPoint(x: ChartAxisValueDouble($0.0, labelSettings: labelSettings), y: ChartAxisValueDouble($0.1))}
    let chartPoints2 = calmness.map{ChartPoint(x: ChartAxisValueDouble($0.0, labelSettings: labelSettings), y: ChartAxisValueDouble($0.1))}
    let chartPoints3 = sadness.map{ChartPoint(x: ChartAxisValueDouble($0.0, labelSettings: labelSettings), y: ChartAxisValueDouble($0.1))}
    
    let xValues = chartPoints.map{$0.x}
    
    let yValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(chartPoints, minSegmentCount: 0, maxSegmentCount: 10, multiple: 10, axisValueGenerator: {ChartAxisValueDouble($0, labelSettings: labelSettings)}, addPaddingSegmentIfEdge: false)
    
    let xModel = ChartAxisModel(axisValues: xValues, axisTitleLabel: ChartAxisLabel(text: "Minutes", settings: labelSettings))
    let yModel = ChartAxisModel(axisValues: yValues, axisTitleLabel: ChartAxisLabel(text: "Emotional Confidence", settings: labelSettings.defaultVertical()))
    let chartFrame = ExamplesDefaults.chartFrame(view.bounds)

    let chartSettings = ExamplesDefaults.iPhoneChartSettingsWithPanZoom
    
    let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: chartFrame, xModel: xModel, yModel: yModel)
    let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
    
    let lineModel = ChartLineModel(chartPoints: chartPoints, lineColor: UIColor.green, animDuration: 1, animDelay: 0)
    let lineModel2 = ChartLineModel(chartPoints: chartPoints2, lineColor: UIColor.red, animDuration: 1, animDelay: 0)
    let lineModel3 = ChartLineModel(chartPoints: chartPoints3, lineColor: UIColor.blue, animDuration: 1, animDelay: 0)
    let chartPointsLineLayer = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel, lineModel2, lineModel3], useView: false)
    
    let thumbSettings = ChartPointsLineTrackerLayerThumbSettings(thumbSize: 10, thumbBorderWidth: 2)
    let trackerLayerSettings = ChartPointsLineTrackerLayerSettings(thumbSettings: thumbSettings)
    
    var currentPositionLabels: [UILabel] = []
    
    let chartPointsTrackerLayer = ChartPointsLineTrackerLayer<ChartPoint, Any>(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lines: [chartPoints, chartPoints2, chartPoints3], lineColor: UIColor.black, animDuration: 1, animDelay: 2, settings: trackerLayerSettings) {chartPointsWithScreenLoc in
      
      currentPositionLabels.forEach{$0.removeFromSuperview()}
      
      for (index, chartPointWithScreenLoc) in chartPointsWithScreenLoc.enumerated() {
        
        let label = UILabel()
        label.text = chartPointWithScreenLoc.chartPoint.description
        label.sizeToFit()
        label.center = CGPoint(x: chartPointWithScreenLoc.screenLoc.x - label.frame.width / 2, y: chartPointWithScreenLoc.screenLoc.y + chartFrame.minY - label.frame.height / 2)
        
        var color: UIColor {
          switch index {
          case 0: return .green
          case 1: return .red
          default: return .blue
          }
        }
        label.backgroundColor = color
        label.textColor = UIColor.white
        
        currentPositionLabels.append(label)
        self.view.addSubview(label)
      }
    }
    
    let settings = ChartGuideLinesDottedLayerSettings(linesColor: UIColor.black, linesWidth: ExamplesDefaults.guidelinesWidth)
    let guidelinesLayer = ChartGuideLinesDottedLayer(xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, settings: settings)
    
    let chart = Chart(
      frame: chartFrame,
      innerFrame: innerFrame,
      settings: chartSettings,
      layers: [
        xAxisLayer,
        yAxisLayer,
        guidelinesLayer,
        chartPointsLineLayer,
        chartPointsTrackerLayer
      ]
    )
    
    if chart.view.superview != nil {
      chart.view.removeFromSuperview()
    }
    view.addSubview(chart.view)
    self.chart = chart
  }
  
  // MARK: - PieChartDelegate
  
  func onSelected(slice: PieSlice, selected: Bool) {
    print("Selected: \(selected), slice: \(slice)")
  }
  
  // MARK: - Models
  
  func createPieModel(happiness: [Emotion], calmness: [Emotion], sadness: [Emotion]) -> [PieSliceModel] {
    let alpha: CGFloat = 0.5
    let hVal: Double = happiness.reduce(0.0, { $0 + $1.value })
    let cVal: Double = calmness.reduce(0.0, { $0 + $1.value })
    let sVal: Double = sadness.reduce(0.0, { $0 + $1.value })
    return [
      PieSliceModel(value: hVal, color: UIColor.blue.withAlphaComponent(alpha)),
      PieSliceModel(value: cVal, color: UIColor.magenta.withAlphaComponent(alpha)),
      PieSliceModel(value: sVal, color: UIColor.orange.withAlphaComponent(alpha))
    ]
  }
  
  // MARK: - Layers
  
  fileprivate func createCustomViewsLayer() -> PieCustomViewsLayer {
    let viewLayer = PieCustomViewsLayer()
    
    let settings = PieCustomViewsLayerSettings()
    settings.viewRadius = 135
    settings.hideOnOverflow = false
    viewLayer.settings = settings
    
    viewLayer.viewGenerator = createViewGenerator()
    
    return viewLayer
  }
  
  fileprivate func createTextLayer() -> PiePlainTextLayer {
    let textLayerSettings = PiePlainTextLayerSettings()
    textLayerSettings.viewRadius = 60
    textLayerSettings.hideOnOverflow = true
    textLayerSettings.label.font = UIFont.systemFont(ofSize: 12)
    
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 1
    textLayerSettings.label.textGenerator = {slice in
      return formatter.string(from: slice.data.percentage * 100 as NSNumber).map{"\($0)%"} ?? ""
    }
    
    let textLayer = PiePlainTextLayer()
    textLayer.settings = textLayerSettings
    return textLayer
  }
  
  fileprivate func createViewGenerator() -> (PieSlice, CGPoint) -> UIView {
    return { slice, center in
      
      let container = UIView()
      container.frame.size = CGSize(width: 100, height: 40)
      container.center = center
      let view = UIImageView()
      view.frame = CGRect(x: 30, y: 0, width: 40, height: 40)
      container.addSubview(view)

      let specialTextLabel = UILabel()
      specialTextLabel.textAlignment = .center
      specialTextLabel.text = {
        switch slice.data.id {
        case 0: return "😄"
        case 1: return "😌"
        case 2: return "😐"
        default: return nil
        }
      }()
      specialTextLabel.font = UIFont.boldSystemFont(ofSize: 18)
      specialTextLabel.sizeToFit()
      specialTextLabel.frame = CGRect(x: 0, y: 40, width: 100, height: 20)
      container.addSubview(specialTextLabel)
      container.frame.size = CGSize(width: 100, height: 60)

      // src of images: www.freepik.com, http://www.flaticon.com/authors/madebyoliver
      let imageName: String? = {
        switch slice.data.id {
        case 0: return "happy"
        case 1: return "calm"
        case 2: return "sad"
        default: return nil
        }
      }()
      
      view.image = imageName.flatMap{UIImage(named: $0)}
      
      return container
    }
  }
}

enum AWSError: Error {
  case error(Error)
}

// https://docs.aws.amazon.com/aws-mobile/latest/developerguide/add-aws-mobile-nosql-database.html
class Face: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
  
  @objc var timestamp: String!
  @objc var happy: NSNumber!
  @objc var sad: NSNumber!
  @objc var calm: NSNumber!
  
  var createdAt: Date! {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
    let date = dateFormatter.date(from: timestamp)
    return date
  }

  class func dynamoDBTableName() -> String {
    return "faces"
  }
  
  class func hashKeyAttribute() -> String {
    return "timestamp"
  }
}

import UIKit
import SwiftCharts

struct ExamplesDefaults {

  fileprivate static var iPadChartSettings: ChartSettings {
    var chartSettings = ChartSettings()
    chartSettings.leading = 20
    chartSettings.top = 20
    chartSettings.trailing = 20
    chartSettings.bottom = 20
    chartSettings.labelsToAxisSpacingX = 10
    chartSettings.labelsToAxisSpacingY = 10
    chartSettings.axisTitleLabelsToLabelsSpacing = 5
    chartSettings.axisStrokeWidth = 1
    chartSettings.spacingBetweenAxesX = 15
    chartSettings.spacingBetweenAxesY = 15
    chartSettings.labelsSpacing = 0
    return chartSettings
  }
  
  fileprivate static var iPhoneChartSettings: ChartSettings {
    var chartSettings = ChartSettings()
    chartSettings.leading = 10
    chartSettings.top = 10
    chartSettings.trailing = 10
    chartSettings.bottom = 10
    chartSettings.labelsToAxisSpacingX = 5
    chartSettings.labelsToAxisSpacingY = 5
    chartSettings.axisTitleLabelsToLabelsSpacing = 4
    chartSettings.axisStrokeWidth = 0.2
    chartSettings.spacingBetweenAxesX = 8
    chartSettings.spacingBetweenAxesY = 8
    chartSettings.labelsSpacing = 0
    return chartSettings
  }
  
  fileprivate static var iPadChartSettingsWithPanZoom: ChartSettings {
    var chartSettings = iPadChartSettings
    chartSettings.zoomPan.panEnabled = true
    chartSettings.zoomPan.zoomEnabled = true
    return chartSettings
  }
  
  fileprivate static var iPhoneChartSettingsWithPanZoom: ChartSettings {
    var chartSettings = iPhoneChartSettings
    chartSettings.zoomPan.panEnabled = true
    chartSettings.zoomPan.zoomEnabled = true
    return chartSettings
  }
  
  static func chartFrame(_ containerBounds: CGRect) -> CGRect {
    return CGRect(x: 0, y: 70, width: containerBounds.size.width, height: containerBounds.size.height - 70)
  }
  
  static var labelSettings: ChartLabelSettings {
    return ChartLabelSettings(font: ExamplesDefaults.labelFont)
  }
  
  static var labelFont: UIFont {
    return ExamplesDefaults.fontWithSize(11)
  }
  
  static var labelFontSmall: UIFont {
    return ExamplesDefaults.fontWithSize(10)
  }
  
  static func fontWithSize(_ size: CGFloat) -> UIFont {
    return UIFont(name: "Helvetica", size: size) ?? UIFont.systemFont(ofSize: size)
  }
  
  static var guidelinesWidth: CGFloat {
    return 0.1
  }
  
  static var minBarSpacing: CGFloat {
    return 5
  }
}


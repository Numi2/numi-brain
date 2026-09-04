import Foundation

/// Deterministic, bounded import of an explicitly selected physical quantity.
/// Metadata describe the source; they are never inferred from a column label.
/// No fitting, filtering, resampling, sign change, or fitted time offset occurs.
public enum PhysicalReferenceImport: Codable, Equatable, Sendable {
  case traceJSON
  case openSimStorage(selection: OpenSimStorageSelection)

  public func decode(_ bytes: Data) throws -> PhysicalTrace {
    try ValidationNumerics.require(!bytes.isEmpty && bytes.count <= 64 * 1024 * 1024,
      "reference input must be 1 byte...64 MiB")
    switch self {
    case .traceJSON:
      let trace = try JSONDecoder().decode(PhysicalTrace.self, from: bytes)
      try trace.validate()
      return trace
    case .openSimStorage(let selection):
      return try OpenSimStorageReader.read(bytes, selection: selection)
    }
  }
}

/// Supports scalar .sto tables, not Vec3/SpatialVec, quaternions, .mot, C3D,
/// multi-quantity derived observables, or implicit unit conversion.
public struct OpenSimStorageSelection: Codable, Equatable, Sendable {
  public let column: String
  public let quantity: String
  public let unit: String
  public let frame: String
  public let coordinate: String
  public let timeOriginSeconds: Double
  public let maximumTimeQuantizationErrorMicroseconds: Double

  public init(column: String, quantity: String, unit: String, frame: String, coordinate: String,
    timeOriginSeconds: Double = 0, maximumTimeQuantizationErrorMicroseconds: Double = 0.01) throws
  {
    self.column = column; self.quantity = quantity; self.unit = unit; self.frame = frame
    self.coordinate = coordinate; self.timeOriginSeconds = timeOriginSeconds
    self.maximumTimeQuantizationErrorMicroseconds = maximumTimeQuantizationErrorMicroseconds
    try validate()
  }

  public func validate() throws {
    try ValidationNumerics.require([column, quantity, unit, frame, coordinate].allSatisfy {
      !$0.isEmpty && $0.utf8.count <= 512
    } && column != "time", "reference column semantics are incomplete")
    try ValidationNumerics.require(timeOriginSeconds.isFinite, "invalid reference time origin")
    try ValidationNumerics.require(maximumTimeQuantizationErrorMicroseconds.isFinite
      && (0...0.5).contains(maximumTimeQuantizationErrorMicroseconds), "invalid time quantization tolerance")
  }
}

public enum OpenSimStorageReader {
  public static func read(_ bytes: Data, selection: OpenSimStorageSelection) throws -> PhysicalTrace {
    try selection.validate()
    try ValidationNumerics.require(!bytes.isEmpty && bytes.count <= 64 * 1024 * 1024,
      "OpenSim source exceeds bounded input size")
    guard let text = String(data: bytes, encoding: .utf8), !text.contains("\0") else {
      throw PhysicalValidationError.invalid("OpenSim source is not scalar UTF-8 text")
    }
    let lines = text.split(whereSeparator: \.isNewline)
    guard let end = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "endheader" }),
      end <= 128, end + 1 < lines.count
    else { throw PhysicalValidationError.invalid("OpenSim scalar table has no bounded endheader") }
    var header: [String: String] = [:]
    for line in lines[..<end] {
      let pair = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
      guard pair.count == 2 else { continue } // First line is the table's name.
      let key = pair[0].lowercased()
      try ValidationNumerics.require(header.updateValue(pair[1], forKey: key) == nil,
        "duplicate OpenSim header key")
    }
    guard let rowsText = header["nrows"], let rows = Int(rowsText), rows >= 2, rows <= 1_048_576,
      let columnsText = header["ncolumns"], let columnCount = Int(columnsText), columnCount >= 2, columnCount <= 4096
    else { throw PhysicalValidationError.invalid("OpenSim table requires bounded nRows and nColumns") }
    if let version = header["version"] {
      try ValidationNumerics.require(version == "1", "unsupported OpenSim storage version")
    }
    if let dataType = header["datatype"] {
      try ValidationNumerics.require(dataType.lowercased() == "double", "only scalar double OpenSim tables are supported")
    }
    if let flag = header["indegrees"] {
      try ValidationNumerics.require(flag == "yes" || flag == "no", "invalid OpenSim angular-unit header")
    }
    // Old OpenSim .sto files without inDegrees are specified as radians.
    // Non-angular quantities are not affected by the table's angular flag.
    if selection.unit == "rad" || selection.unit == "deg" {
      let declared = header["indegrees"] == "yes" ? "deg" : "rad"
      try ValidationNumerics.require(selection.unit == declared, "OpenSim angular units disagree; implicit conversion is forbidden")
    }
    let labels = lines[end + 1].split(whereSeparator: \.isWhitespace).map(String.init)
    guard labels.count == columnCount, labels.first == "time", Set(labels).count == labels.count,
      let selectedColumn = labels.firstIndex(of: selection.column)
    else { throw PhysicalValidationError.invalid("OpenSim time/column labels do not match the selection") }
    let dataLines = lines.dropFirst(end + 2)
    try ValidationNumerics.require(dataLines.count == rows, "OpenSim row count does not match header")
    var times: [UInt64] = [], values: [Double] = []
    times.reserveCapacity(rows); values.reserveCapacity(rows)
    var previousSeconds: Double?
    for line in dataLines {
      let cells = line.split(whereSeparator: \.isWhitespace)
      try ValidationNumerics.require(cells.count == columnCount, "ragged OpenSim row")
      // Validate every scalar, not just the selected column, so a corrupt or
      // structured source cannot be partially accepted as a scalar table.
      let numbers = try cells.map { cell -> Double in
        guard let number = Double(cell), number.isFinite else {
          throw PhysicalValidationError.invalid("non-finite or nonscalar OpenSim cell")
        }
        return number
      }
      let seconds = numbers[0]
      try ValidationNumerics.require(previousSeconds == nil || seconds > previousSeconds!,
        "OpenSim time must strictly increase")
      previousSeconds = seconds
      let micros = (seconds - selection.timeOriginSeconds) * 1_000_000
      let rounded = micros.rounded(.toNearestOrEven)
      try ValidationNumerics.require(micros.isFinite && micros >= 0 && rounded < Double(UInt64.max)
        && abs(micros - rounded) <= selection.maximumTimeQuantizationErrorMicroseconds,
        "OpenSim time lies outside its declared origin, UInt64 clock, or quantization budget")
      let time = UInt64(rounded)
      try ValidationNumerics.require(times.last == nil || time > times.last!,
        "OpenSim times alias after microsecond quantization")
      times.append(time); values.append(numbers[selectedColumn])
    }
    return try PhysicalTrace(quantity: selection.quantity, unit: selection.unit, frame: selection.frame,
      coordinate: selection.coordinate, timestampsMicroseconds: times, values: values,
      validity: [Bool](repeating: true, count: values.count))
  }
}

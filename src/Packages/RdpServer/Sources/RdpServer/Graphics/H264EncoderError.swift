/// Failures of the hardware H.264 encoder.
public enum H264EncoderError: Error, CustomStringConvertible {
    case sessionCreationFailed(Int32)
    case encodingFailed(Int32)
    case noPixelBuffer

    public var description: String {
        switch self {
        case .sessionCreationFailed(let status): "cannot create the H.264 encoder (\(status))"
        case .encodingFailed(let status): "H.264 encoding failed (\(status))"
        case .noPixelBuffer: "no pixel buffer for the H.264 encoder"
        }
    }
}

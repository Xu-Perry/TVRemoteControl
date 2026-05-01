import Foundation
import SonyRemoteCore

public struct SSDPDeviceDescriptionParser: Sendable {
    public init() {}

    public func parse(data: Data, location: URL) throws -> DiscoveredBRAVIADevice? {
        guard let xml = String(data: data, encoding: .utf8) else {
            throw DiscoveryError.malformedDeviceDescription
        }

        let lowercaseXML = xml.lowercased()
        let isSony = lowercaseXML.contains("sony")
        let isBRAVIA = lowercaseXML.contains("bravia") || lowercaseXML.contains("scalarwebapi")
        guard isSony || isBRAVIA else {
            return nil
        }

        guard let host = URLComponents(url: location, resolvingAgainstBaseURL: false)?.host, !host.isEmpty else {
            throw DiscoveryError.malformedDeviceDescription
        }

        let friendlyName = displayName(
            friendlyName: firstXMLValue(named: "friendlyName", in: xml),
            fallback: host
        )
        let uniqueIdentifier = firstXMLValue(named: "UDN", in: xml)
            ?? firstXMLValue(named: "serialNumber", in: xml)
        let controlURL = firstXMLValue(named: "controlURL", in: xml)
            .flatMap(URL.init(string:))
        let port = controlURL?.port ?? 80

        return DiscoveredBRAVIADevice(
            name: friendlyName,
            host: host,
            port: port,
            uniqueIdentifier: uniqueIdentifier,
            connectionReadiness: .connectable
        )
    }

    private func displayName(friendlyName: String?, fallback: String) -> String {
        let trimmedFriendlyName = friendlyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedFriendlyName.isEmpty {
            return trimmedFriendlyName
        }

        return fallback
    }

    private func firstXMLValue(named name: String, in xml: String) -> String? {
        guard let openRange = xml.range(of: "<\(name)>", options: [.caseInsensitive]),
              let closeRange = xml.range(of: "</\(name)>", options: [.caseInsensitive], range: openRange.upperBound..<xml.endIndex)
        else {
            return nil
        }

        let rawValue = String(xml[openRange.upperBound..<closeRange.lowerBound])
        let value = rawValue
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

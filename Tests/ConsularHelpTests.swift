import XCTest
import MapKit
@testable import UsefulTravelClock

final class ConsularHelpTests: XCTestCase {
    func testClosestReturnedOfficeIgnoresUnrelatedPlaces() {
        let origin = CLLocation(latitude: 35, longitude: 139)
        func place(_ name: String, _ latitude: Double) -> MKMapItem {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 139)))
            item.name = name
            return item
        }
        let cafe = place("Cafe", 35.001)
        let embassy = place("US Embassy", 35.1)
        let consulate = place("US Consulate", 35.01)
        XCTAssertTrue(ConsularResults.nearest([cafe, embassy, consulate], to: origin) === consulate)
        XCTAssertNil(ConsularResults.nearest([cafe], to: origin))
    }
    func testCountrySearchSupportsCodesAndNames() {
        XCTAssertTrue(PassportCountry.named("US")?.matches("United States") == true)
        XCTAssertTrue(PassportCountry.named("JP")?.matches("jp") == true)
        XCTAssertNil(PassportCountry.named("invalid"))
    }
}

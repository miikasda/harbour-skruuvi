import QtQuick 2.0
import Sailfish.Silica 1.0 as S
import "../modules/Opal/About" as A

A.AboutPageBase {
    appName: "Skruuvi"
    appIcon: Qt.resolvedUrl("images/skruuvi-icon.png")
    appVersion: "2.0.0"
    description: "Reader for Ruuvi sensors on Sailfish OS"
    authors: "Miika Malin"
    licenses: A.License { spdxId: "GPL-3.0-or-later" }
    changelogItems: [
        // add new entries at the top
        A.ChangelogItem {
            version: "v2.0.0"
            date: "2025-12-24"
            paragraphs: "Added support for scanning new measurements from Bluetooth advertisements in the background, " +
                        "and added support for the new Ruuvi Air indoor air quality sensor. " +
                        "Improved efficiency for data fetching and plotting, and added a low battery indication. " +
                        "Refined the cover page experience, and updated the app icons to follow the user’s theme for better visibility. " +
                        "For the complete list of changes, see the GitHub release."
        },
        A.ChangelogItem {
            version: "v1.3.0"
            date: "2024-07-24"
            paragraphs: "Added support for reading voltage and movement counter from RuuviTag, " +
                        "and enabled time selection in data plotting."
        },
        A.ChangelogItem {
            version: "v1.2.0"
            date: "2023-11-23"
            paragraphs: "Changed to semantic versioning starting from this release. Changes: " +
                        "Added about page (opens by pressing Skruuvi-logo), support for " +
                        "fullscreen plots (press the graph to open it), notification if " +
                        "bluetooth is off when scanning for devices, support for CSV exports and " +
                        "support for selecting only start or end time for plot. Fixed negative " +
                        "temperature readings. Also other small tweaks, for full change history " +
                        "check the github release."
        },
        A.ChangelogItem {
            version: "v1.1"
            date: "2023-07-04"
            paragraphs: "Fixed time button in fetch setup page, " +
                        "added support for armv7hl architecture"
        },
        A.ChangelogItem {
            version: "v1.0"
            date: "2023-06-26"
            paragraphs: "Initial release"
        }
    ]
    attributions: [
        A.Attribution {
            name: "Bleak (0.20.2)"
            entries: ["Henrik Blidh"]
            licenses: A.License { spdxId: "MIT" }
            sources: "https://github.com/hbldh/bleak"
        },
        A.Attribution {
            name: "Data graphs"
            entries: ["Basil Semuonov"]
            sources: "https://github.com/custodian/harbour-systemmonitor"
        },
        A.OpalAboutAttribution {}
    ]
    sourcesUrl: "https://github.com/miikasda/harbour-skruuvi"
    donations.text: "If you enjoy Skruuving so much that you would like " +
                    "to buy me a cup of coffee, you can do so by GitHub " +
                    "Sponsors below"
    donations.services: [
        A.DonationService {
            name: "GitHub Sponsors"
            url: "https://github.com/sponsors/miikasda"
        }
    ]
}

import QtQuick 2.0
import Sailfish.Silica 1.0 as S
import "../modules/Opal/About" as A

A.AboutPageBase {
    appName: "Skruuvi"
    appIcon: Qt.resolvedUrl("images/skruuvi-icon.png")
    appVersion: "1.1"
    description: "Reader for Ruuvi sensors on Sailfish OS"
    authors: "Miika Malin"
    licenses: A.License { spdxId: "GPL-3.0-or-later" }
    changelogItems: [
        // add new entries at the top
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

import XCTest

final class ScreenTourTests: XCTestCase {

    let app = XCUIApplication()
    let screenshotDir = "/Users/aura/.openclaw/workspace/screens"

    override func setUp() {
        continueAfterFailure = true
        app.launchEnvironment = [
            "HYPR_DEBUG_SERVER": "http://192.168.1.210:8096",
            "HYPR_DEBUG_TOKEN": "549067dd0fbe43649be6d88e447eaf99",
            "HYPR_DEBUG_USERID": "0f1acd224e82402f85260357fb48af3a"
        ]
        // Clear screenshots dir
        try? FileManager.default.removeItem(atPath: screenshotDir)
        try? FileManager.default.createDirectory(atPath: screenshotDir, withIntermediateDirectories: true)
        app.launch()
    }

    func testScreenTour() throws {
        let remote = XCUIRemote.shared

        // Wait for home to load
        let homeTab = app.tabBars.buttons["Home"]
        guard homeTab.waitForExistence(timeout: 10) else {
            saveScreenshot(name: "00_ServerConnection")
            return
        }

        // ---- HOME SCREEN ----
        sleep(4) // Let images load
        saveScreenshot(name: "01_Home_Default")

        // Scroll right to see more items
        remote.press(.right)
        sleep(1)
        saveScreenshot(name: "02_Home_FocusRight")

        // Scroll down to see more rows
        remote.press(.down)
        sleep(1)
        saveScreenshot(name: "03_Home_Row2")

        remote.press(.down)
        sleep(1)
        saveScreenshot(name: "04_Home_Row3")

        remote.press(.down)
        sleep(1)
        saveScreenshot(name: "05_Home_Row4")

        // ---- MEDIA DETAIL ----
        // Go back to top row, first item
        remote.press(.up)
        sleep(1)
        remote.press(.up)
        sleep(1)
        remote.press(.up)
        sleep(1)
        remote.press(.left)
        remote.press(.left)
        remote.press(.left)
        remote.press(.left)
        sleep(1)

        // Select first Continue Watching item
        remote.press(.select)
        sleep(3)
        saveScreenshot(name: "06_Detail_Top")

        // Scroll down to see more detail info
        remote.press(.down)
        sleep(1)
        saveScreenshot(name: "07_Detail_Middle")

        remote.press(.down)
        sleep(1)
        saveScreenshot(name: "08_Detail_Bottom")

        // ---- PLAY VIDEO ----
        // Go back up to the Play button area
        remote.press(.up)
        sleep(1)
        remote.press(.up)
        sleep(1)

        // Try to find and tap the Play button by accessibility
        let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Play'")).firstMatch
        if playButton.waitForExistence(timeout: 3) {
            // Focus should be near Play — press select
            remote.press(.select)
            sleep(5)
            saveScreenshot(name: "09_Player_Active")

            // Toggle overlay
            remote.press(.select)
            sleep(2)
            saveScreenshot(name: "10_Player_Overlay")

            // Exit player
            remote.press(.menu)
            sleep(1)
            remote.press(.menu)
            sleep(2)
        } else {
            // Fallback: try pressing select on what's focused
            remote.press(.select)
            sleep(5)
            saveScreenshot(name: "09_Player_Fallback")
            remote.press(.menu)
            sleep(2)
        }

        saveScreenshot(name: "11_BackFromPlayer")

        // ---- GO BACK TO HOME ----
        remote.press(.menu)
        sleep(2)

        // ---- SEARCH TAB ----
        // Navigate up to tab bar
        for _ in 0..<10 { remote.press(.up); usleep(150_000) }
        sleep(1)
        // Tab right to Search
        remote.press(.right)
        sleep(2)
        saveScreenshot(name: "12_Search_Tab")

        // ---- SETTINGS TAB ----
        for _ in 0..<10 { remote.press(.up); usleep(150_000) }
        sleep(1)
        remote.press(.right)
        sleep(2)
        saveScreenshot(name: "13_Settings_Tab")

        // Scroll down in settings
        remote.press(.down)
        sleep(1)
        saveScreenshot(name: "14_Settings_Scroll")
    }

    private func saveScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let data = screenshot.pngRepresentation
        let url = URL(fileURLWithPath: screenshotDir).appendingPathComponent("\(name).png")
        try? data.write(to: url)
    }
}

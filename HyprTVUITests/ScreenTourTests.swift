import XCTest

/// UI test that navigates through every screen and takes screenshots.
final class ScreenTourTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchEnvironment = [
            "HYPR_DEBUG_SERVER": "http://192.168.1.210:8096",
            "HYPR_DEBUG_TOKEN": "549067dd0fbe43649be6d88e447eaf99",
            "HYPR_DEBUG_USERID": "0f1acd224e82402f85260357fb48af3a"
        ]
        app.launch()
    }

    func testScreenTour() throws {
        let remote = XCUIRemote.shared

        // Wait for home screen to load
        let homeTab = app.tabBars.buttons["Home"]
        let exists = homeTab.waitForExistence(timeout: 10)

        if exists {
            // ---- HOME SCREEN ----
            sleep(3)
            takeScreenshot(name: "01_Home")

            // Navigate right through first row
            remote.press(.right)
            sleep(1)
            takeScreenshot(name: "02_Home_FocusRight")

            remote.press(.right)
            sleep(1)
            remote.press(.right)
            sleep(1)
            takeScreenshot(name: "03_Home_MoreItems")

            // Navigate down to next row
            remote.press(.down)
            sleep(1)
            takeScreenshot(name: "04_Home_SecondRow")

            remote.press(.down)
            sleep(1)
            takeScreenshot(name: "05_Home_ThirdRow")

            // ---- SELECT A MEDIA ITEM (DETAIL VIEW) ----
            remote.press(.up)
            sleep(1)
            remote.press(.up)
            sleep(1)
            remote.press(.left)
            remote.press(.left)
            remote.press(.left)
            sleep(1)

            // Select first item to go to detail view
            remote.press(.select)
            sleep(3)
            takeScreenshot(name: "06_MediaDetail")

            // Scroll down in detail view
            remote.press(.down)
            sleep(1)
            takeScreenshot(name: "07_MediaDetail_ScrollDown")

            // Go back to home
            remote.press(.menu)
            sleep(2)

            // ---- SEARCH TAB ----
            // Navigate up to tab bar
            for _ in 0..<6 { remote.press(.up); usleep(300_000) }
            sleep(1)
            // Move to Search tab
            remote.press(.right)
            sleep(1)
            remote.press(.select)
            sleep(2)
            takeScreenshot(name: "08_Search")

            // ---- SETTINGS TAB ----
            // Navigate up to tab bar
            for _ in 0..<6 { remote.press(.up); usleep(300_000) }
            sleep(1)
            remote.press(.right)
            sleep(1)
            remote.press(.select)
            sleep(2)
            takeScreenshot(name: "09_Settings")

            // ---- BACK TO HOME, TRY PLAYING ----
            // Navigate back to Home tab
            for _ in 0..<6 { remote.press(.up); usleep(300_000) }
            sleep(1)
            remote.press(.left)
            sleep(1)
            remote.press(.left)
            sleep(1)
            remote.press(.select)
            sleep(2)

            // Navigate to first item and select it
            remote.press(.down)
            sleep(1)
            remote.press(.select)
            sleep(3)
            takeScreenshot(name: "10_DetailBeforePlay")

            // Press down to Play button and select
            remote.press(.down)
            sleep(1)
            remote.press(.select)
            sleep(5) // Wait for player to load
            takeScreenshot(name: "11_Player")

            // Toggle overlay by pressing select
            remote.press(.select)
            sleep(1)
            takeScreenshot(name: "12_PlayerOverlay")

            // Exit player with menu
            remote.press(.menu)
            sleep(1)
            remote.press(.menu)
            sleep(2)
            takeScreenshot(name: "13_AfterPlayerExit")

        } else {
            takeScreenshot(name: "00_ServerConnection")
        }
    }

    private func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
